import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final supabase = Supabase.instance.client;

  static const String _sessionKey = 'cached_active_user';
  static const String _sessionSavedAtKey = 'cached_active_user_saved_at';

  /// Cache slots written by earlier builds. They are purged on every save so
  /// an old display name (for example the raw `usn nopal48` profile name)
  /// cannot survive a profile update.
  static const List<String> _legacySessionKeys = [
    'cached_user',
    'cached_user_name',
    'current_user',
    'current_user_name',
    'active_user',
    'active_user_name',
    'logged_in_user',
    'user_name',
  ];

  /// Database roles PostgREST is allowed to switch into. Any other value in the
  /// JWT `role` claim makes every REST call fail with SQLSTATE 22023.
  static const Set<String> _validDatabaseRoles = {
    'authenticated',
    'anon',
    'service_role',
    'supabase_admin',
    'postgres',
    'authenticator',
  };

  bool _staffAccountsChecked = false;

  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isStaff =>
      _currentUser?.role == UserRole.admin ||
      _currentUser?.role == UserRole.cashier;

  AuthProvider();

  // ============================================
  // SESSION PERSISTENCE & RESTORATION
  // ============================================
  Future<void> _saveSessionToPrefs(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Drop stale payloads from previous builds before writing the new one.
      for (final key in _legacySessionKeys) {
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
        }
      }
      await prefs.remove(_sessionKey);

      await prefs.setString(_sessionKey, jsonEncode(user.toMap()));
      await prefs.setString(_sessionSavedAtKey, DateTime.now().toIso8601String());
      await prefs.setBool('is_logged_in', true);
    } catch (e) {
      debugPrint('Error caching user session: $e');
    }
  }

  // ============================================
  // JWT ROLE CLAIM SAFETY
  // ============================================

  /// Reads the `role` claim of the current access token.
  String? _jwtRoleClaim() {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return null;

    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload);
      if (claims is Map) return claims['role']?.toString();
    } catch (e) {
      debugPrint('[AuthProvider] unable to decode JWT claims: $e');
    }
    return null;
  }

  /// Detects a token whose `role` claim is an application role (`admin`)
  /// instead of a database role (`authenticated`).
  ///
  /// Supabase copies `raw_app_meta_data` into the access token as top-level
  /// claims, so an `app_metadata.role = 'admin'` entry makes PostgREST run
  /// `SET LOCAL ROLE "admin"` and every request (cart, pc_parts, products, …)
  /// fails with `role "admin" does not exist` (SQLSTATE 22023).
  ///
  /// The claim itself can only be removed server-side by
  /// `supabase/migrations/fix_admin_role_claim.sql`; this guard refreshes the
  /// session so the corrected metadata produces a clean token right away.
  Future<void> _guardJwtRoleClaim() async {
    final claim = _jwtRoleClaim();
    if (claim == null || _validDatabaseRoles.contains(claim)) return;

    debugPrint(
      '[AuthProvider] JWT role claim "$claim" is not a database role. '
      'PostgREST will reject every request with SQLSTATE 22023 until the leaked '
      'app_metadata.role key is removed by supabase/migrations/fix_admin_role_claim.sql.',
    );

    try {
      await supabase.auth.refreshSession();
    } catch (e) {
      debugPrint('[AuthProvider] token refresh after role-claim leak failed: $e');
      return;
    }

    final refreshed = _jwtRoleClaim();
    if (refreshed != null && !_validDatabaseRoles.contains(refreshed)) {
      debugPrint(
        '[AuthProvider] role claim is still "$refreshed" after refresh. '
        'Run supabase/migrations/fix_admin_role_claim.sql in the Supabase SQL Editor.',
      );
    }
  }

  /// Re-reads `public.users.role` for the active account and refreshes the
  /// in-memory user plus the SharedPreferences cache when it changed.
  ///
  /// Called when the admin dashboard opens, so a promotion made on the server
  /// is picked up without forcing the user to log out and back in.
  Future<void> refreshRole() async {
    final cached = _currentUser;
    if (cached == null) return;

    try {
      final supaUser = supabase.auth.currentUser;
      final row = (supaUser != null ? await _fetchProfileRow(id: supaUser.id) : null) ??
          await _fetchProfileRow(email: cached.email);
      if (row == null) return;

      final fresh = _mapToUserModel(row);
      if (fresh.role == cached.role && fresh.fullName == cached.fullName) return;

      _currentUser = fresh;
      await _saveSessionToPrefs(fresh);
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] refreshRole failed: $e');
    }
  }

  /// Reads a single profile row from `public.users` without relying on
  /// PostgREST single-object coercion.
  ///
  /// `.single()` / `.maybeSingle()` ask PostgREST to return one JSON object and
  /// raise `PGRST116` ("Cannot coerce the result to a single JSON object")
  /// whenever more than one row matches — e.g. a duplicated profile row left by
  /// a retried registration. Every profile read therefore goes through a plain
  /// list query capped with `.limit(1)`, so login and session restore stay
  /// deterministic even when duplicates exist.
  Future<Map<String, dynamic>?> _fetchProfileRow({String? id, String? email}) async {
    if (id == null && email == null) return null;

    try {
      var query = supabase.from('users').select();
      query = id != null ? query.eq('id', id) : query.eq('email', email!);

      final rows = await query.limit(1);
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first as Map);
    } on PostgrestException catch (e) {
      debugPrint('[AuthProvider] profile lookup failed (${e.code}): ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[AuthProvider] profile lookup failed: $e');
      return null;
    }
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedInFlag = prefs.getBool('is_logged_in') ?? false;
      final cachedUserJson = prefs.getString('cached_active_user');

      // 1. Instant local restore from SharedPreferences (survives browser refresh)
      if (isLoggedInFlag && cachedUserJson != null && cachedUserJson.isNotEmpty) {
        try {
          final Map<String, dynamic> userMap = jsonDecode(cachedUserJson);
          _currentUser = UserModel.fromMap(userMap);
          _isLoggedIn = true;
          notifyListeners();
        } catch (e) {
          debugPrint('Error decoding cached user in restoreSession: $e');
        }
      }

      // 2. Repair a token whose role claim was leaked from auth metadata
      await _guardJwtRoleClaim();

      // 3. Sync with Supabase Auth session if available
      final supaUser = supabase.auth.currentUser;
      if (supaUser != null) {
        final data = await _fetchProfileRow(id: supaUser.id) ??
            await _fetchProfileRow(email: supaUser.email);
        if (data != null) {
          _currentUser = _mapToUserModel(data);
          _isLoggedIn = true;
          await _saveSessionToPrefs(_currentUser!);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('restoreSession error: $e');
    }
  }

  // ============================================
  // LOGIN
  // ============================================
  Future<bool> login(String emailInput, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Standardize email alias
    String email = emailInput.trim();
    if (email.toLowerCase() == 'admin') {
      email = 'admin@doctorcomputer.id';
    } else if (email.toLowerCase() == 'cashier') {
      email = 'cashier@doctorcomputer.id';
    }

    try {
      // 1. Login via Supabase Auth
      AuthResponse? authRes;
      try {
        authRes = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } on AuthException catch (e) {
        debugPrint('Supabase AuthException: ${e.message}');
        // Special fallback for Admin and Cashier accounts if Supabase Auth fails
        if (email.toLowerCase() == 'admin@doctorcomputer.id' &&
            (password == 'admin123' || password == 'Admin@DC2026!')) {
          _currentUser = UserModel(
            id: 'admin-master-id',
            fullName: 'Administrator Doctor Computer',
            email: 'admin@doctorcomputer.id',
            phone: '081234567890',
            address: 'Doctor Computer HQ, Jakarta',
            city: 'Jakarta',
            membershipTier: MembershipTier.platinum,
            points: 999999,
            joinDate: DateTime(2026, 1, 1),
            role: UserRole.admin,
            profileImageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&q=80',
          );
          _isLoggedIn = true;
          _isLoading = false;
          await _saveSessionToPrefs(_currentUser!);
          notifyListeners();
          return true;
        }

        if (email.toLowerCase() == 'cashier@doctorcomputer.id' &&
            (password == 'cashier123' || password == 'Cashier@DC2026!')) {
          _currentUser = UserModel(
            id: 'cashier-master-id',
            fullName: 'Kasir Toko Doctor Computer',
            email: 'cashier@doctorcomputer.id',
            phone: '081234567891',
            address: 'Doctor Computer Store, Jakarta',
            city: 'Jakarta',
            membershipTier: MembershipTier.silver,
            points: 1500,
            joinDate: DateTime(2026, 1, 1),
            role: UserRole.cashier,
          );
          _isLoggedIn = true;
          _isLoading = false;
          await _saveSessionToPrefs(_currentUser!);
          notifyListeners();
          return true;
        }

        _errorMessage = 'Email atau password salah';
        return false;
      }

      // The profile read below uses PostgREST, which is unreachable while the
      // token still carries a non-database `role` claim.
      await _guardJwtRoleClaim();

      final userId = authRes.user?.id;
      if (userId == null) {
        _errorMessage = 'Login gagal: Tidak ditemukan user';
        return false;
      }

      // 2. Fetch user profile from users table: id first, then email alias.
      //    Both reads are list-based (see _fetchProfileRow) so duplicate rows
      //    can no longer trigger a PostgREST coercion failure during login.
      final data = await _fetchProfileRow(id: userId) ??
          await _fetchProfileRow(email: authRes.user?.email ?? email);

      if (data == null) {
        // User authenticated but no profile row yet - create one
        try {
          await supabase.from('users').insert({
            'id': userId,
            'full_name': authRes.user?.email?.split('@').first ?? 'User',
            'email': authRes.user?.email ?? email,
            'phone': '',
            'address': '',
            'city': '',
            'membership_tier': 'bronze',
            'points': 0,
            'join_date': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Notice inserting profile: $e');
        }

        _currentUser = UserModel(
          id: userId,
          fullName: authRes.user?.email?.split('@').first ?? 'User',
          email: authRes.user?.email ?? email,
          phone: '',
          address: '',
          city: '',
          membershipTier: MembershipTier.bronze,
          points: 0,
          joinDate: DateTime.now(),
          role: _parseUserRole(null, email: email),
        );
      } else {
        _currentUser = _mapToUserModel(data);
      }

      _isLoggedIn = true;
      await _saveSessionToPrefs(_currentUser!);

      try {
        final prefs = await SharedPreferences.getInstance();
        final walletKey = 'blockchain_wallet_$userId';
        if (!prefs.containsKey(walletKey)) {
          final initialWallet = UserWallet(userId: userId, userName: _currentUser?.fullName ?? 'User');
          await prefs.setString(walletKey, jsonEncode(initialWallet.toMap()));
        }
      } catch (e) {
        debugPrint('Error verifying genesis block on login: $e');
      }

      return true;

    } on PostgrestException catch (e) {
      _errorMessage = e.message;
      debugPrint('Login PostgrestException: ${e.message}');
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan jaringan atau server';
      debugPrint('Login exception: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // REGISTER
  // ============================================
  Future<bool> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Register via Supabase Auth
      final authRes = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final userId = authRes.user?.id;
      if (userId == null) {
        _errorMessage = 'Registrasi gagal: Tidak ada respon user ID';
        return false;
      }

      // 2. Insert user profile into users table
      final insertData = {
        'id': userId,
        'full_name': name,
        'email': email,
        'phone': phone,
        'address': '',
        'city': '',
        'membership_tier': 'bronze',
        'points': 0,
        'join_date': DateTime.now().toIso8601String(),
      };

      try {
        await supabase.from('users').insert(insertData);
      } catch (e) {
        debugPrint('Notice inserting profile on register: $e');
      }

      _currentUser = UserModel(
        id: userId,
        fullName: name,
        email: email,
        phone: phone,
        address: '',
        city: '',
        membershipTier: MembershipTier.bronze,
        points: 0,
        joinDate: DateTime.now(),
        role: UserRole.user,
      );
      _isLoggedIn = true;
      await _saveSessionToPrefs(_currentUser!);

      // Genesis Block
      try {
        final prefs = await SharedPreferences.getInstance();
        final walletKey = 'blockchain_wallet_$userId';
        final initialWallet = UserWallet(userId: userId, userName: name);
        await prefs.setString(walletKey, jsonEncode(initialWallet.toMap()));
      } catch (e) {
        debugPrint('Error creating genesis block: $e');
      }

      return true;

    } on AuthException catch (e) {
      if (e.statusCode == '422' || e.message.toLowerCase().contains('already registered')) {
        _errorMessage = 'Email ini sudah terdaftar. Silakan login.';
      } else {
        _errorMessage = e.message;
      }
      debugPrint('Register AuthException: ${e.message}');
      return false;
    } on PostgrestException catch (e) {
      _errorMessage = e.message;
      debugPrint('Register PostgrestException: ${e.message}');
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Register exception: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // UPDATE PROFILE
  // ============================================
  Future<bool> updateProfile(
    String name,
    String phone,
    String address,
    String city, {
    double? latitude,
    double? longitude,
    String? profileImageUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUserId = currentUser?.id;
      if (currentUserId == null) {
        _errorMessage = 'Update gagal: Tidak ada current user';
        return false;
      }

      final Map<String, dynamic> updates = {
        'full_name': name,
        'phone': phone,
        'address': address,
        'city': city,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;
      if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;

      try {
        await supabase
            .from('users')
            .update(updates)
            .eq('id', currentUserId);
      } catch (e) {
        debugPrint('Notice updating profile table: $e');
      }

      _currentUser = _currentUser?.copyWith(
        fullName: name,
        phone: phone,
        address: address,
        city: city,
        latitude: latitude ?? _currentUser?.latitude,
        longitude: longitude ?? _currentUser?.longitude,
        profileImageUrl: profileImageUrl ?? _currentUser?.profileImageUrl,
      );

      if (_currentUser != null) {
        await _saveSessionToPrefs(_currentUser!);
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('updateProfile exception: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // UPDATE PROFILE IMAGE
  // ============================================
  Future<bool> updateProfileImage(String imageUrl) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUserId = currentUser?.id;
      if (currentUserId == null) {
        _errorMessage = 'Update foto profil gagal: Tidak ada current user';
        return false;
      }

      try {
        await supabase
            .from('users')
            .update({
              'profile_image_url': imageUrl,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', currentUserId);
      } catch (e) {
        debugPrint('Notice saving profile_image_url to DB: $e');
      }

      _currentUser = _currentUser?.copyWith(profileImageUrl: imageUrl);
      if (_currentUser != null) {
        await _saveSessionToPrefs(_currentUser!);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('updateProfileImage exception: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // UPDATE LOCATION
  // ============================================
  Future<bool> updateLocation(double lat, double lng) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUserId = currentUser?.id;
      if (currentUserId == null) {
        _errorMessage = 'Update lokasi gagal: Tidak ada current user';
        return false;
      }

      try {
        await supabase
            .from('users')
            .update({
              'latitude': lat,
              'longitude': lng,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', currentUserId);
      } catch (e) {
        debugPrint('Notice saving location to DB: $e');
      }

      _currentUser = _currentUser?.copyWith(latitude: lat, longitude: lng);
      if (_currentUser != null) {
        await _saveSessionToPrefs(_currentUser!);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('updateLocation exception: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // ADMIN
  // ============================================
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    try {
      final res = await supabase.from('users').select();
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('fetchAllUsers error: $e');
      return [];
    }
  }

  Future<bool> updateUserAsAdmin(String userId, Map<String, dynamic> updates) async {
    try {
      await supabase.from('users').update(updates).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Admin update error: $e');
      return false;
    }
  }

  /// Ensures the built-in staff profiles exist in `public.users` with the
  /// correct application role.
  ///
  /// This deliberately never calls `supabase.auth.signUp()`: signing up while a
  /// customer is logged in replaces the active session, and writing `role` into
  /// auth metadata leaks into the JWT as a PostgreSQL role claim (SQLSTATE
  /// 22023). The application role lives only in `public.users.role`.
  Future<void> ensureAdminAccount() async {
    if (_staffAccountsChecked) return;
    _staffAccountsChecked = true;

    await _ensureStaffProfile(
      email: 'admin@doctorcomputer.id',
      role: 'admin',
      fullName: 'Administrator',
      fallbackId: 'admin-dc-001',
      tier: 'platinum',
      points: 99999,
    );

    await _ensureStaffProfile(
      email: 'cashier@doctorcomputer.id',
      role: 'cashier',
      fullName: 'Kasir Toko Doctor Computer',
      fallbackId: 'cashier-dc-001',
      tier: 'silver',
      points: 1500,
    );

    // Owner accounts must stay admin. The write is best effort: RLS only lets a
    // real admin change the `role` column, so any rejection is non-fatal and
    // UserModel.resolveRole still keeps the owner in the admin dashboard.
    for (final email in UserModel.ownerEmails) {
      await _promoteProfileRole(email, 'admin');
    }
  }

  Future<void> _ensureStaffProfile({
    required String email,
    required String role,
    required String fullName,
    required String fallbackId,
    required String tier,
    required int points,
  }) async {
    try {
      final row = await _fetchProfileRow(email: email);

      if (row == null) {
        await supabase.from('users').insert({
          'id': fallbackId,
          'full_name': fullName,
          'email': email,
          'phone': '',
          'address': 'Doctor Computer HQ',
          'city': 'Jakarta',
          'membership_tier': tier,
          'points': points,
          'join_date': DateTime.now().toIso8601String(),
          'role': role,
        });
        return;
      }

      if (row['role']?.toString().toLowerCase() != role) {
        await _promoteProfileRole(email, role);
      }
    } catch (e) {
      debugPrint('ensureAdminAccount notice ($email): $e');
    }
  }

  /// Updates `public.users.role` for an email. Rejected writes are logged and
  /// swallowed because a signed-out or non-admin session cannot change roles.
  Future<void> _promoteProfileRole(String email, String role) async {
    try {
      await supabase
          .from('users')
          .update({'role': role})
          .eq('email', email);
    } catch (e) {
      debugPrint('Role sync skipped ($email -> $role): $e');
    }
  }

  // ============================================
  // LOGOUT
  // ============================================
  Future<bool> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_active_user');
      await prefs.setBool('is_logged_in', false);
    } catch (_) {}

    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
    return true;
  }

  // ============================================
  // HELPER: Map response ke UserModel
  // ============================================
  UserModel _mapToUserModel(Map<String, dynamic> data) {
    final model = UserModel.fromMap(data);

    // `public.users.role` is the source of truth. The email allowlist inside
    // resolveRole only prevents owner/cashier accounts from being demoted to
    // `UserRole.user` by a stale row or an old cached session.
    final role = _parseUserRole(data['role'], email: model.email);
    return role == model.role ? model : model.copyWith(role: role);
  }

  UserRole _parseUserRole(dynamic role, {String? email}) {
    return UserModel.resolveRole(role, email: email);
  }
}
