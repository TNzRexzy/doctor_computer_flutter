import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/services/biometric_credential_store.dart';

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

  static const String _kInvalidCredentialsMsg = 'Email atau password salah';

  // Akun fallback lokal (dipakai jika Supabase Auth menolak).
  bool _isFallbackAdmin(String email, String password) =>
      email.toLowerCase() == 'admin@doctorcomputer.id' &&
      (password == 'admin123' || password == 'Admin@DC2026!');

  bool _isFallbackCashier(String email, String password) =>
      email.toLowerCase() == 'cashier@doctorcomputer.id' &&
      (password == 'cashier123' || password == 'Cashier@DC2026!');

  AuthProvider();

  // ============================================
  // SESSION PERSISTENCE & RESTORATION
  // ============================================
  Future<void> _saveSessionToPrefs(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_active_user', jsonEncode(user.toMap()));
      await prefs.setBool('is_logged_in', true);
      // Tombol biometrik di halaman login mengikuti akun yang terakhir login
      await BiometricCredentialStore.setLastLoginUser(user.id);
    } catch (e) {
      debugPrint('Error caching user session: $e');
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

      // 2. Sync with Supabase Auth session if available
      final supaUser = supabase.auth.currentUser;
      if (supaUser != null) {
        try {
          final List res = await supabase
              .from('users')
              .select()
              .eq('id', supaUser.id)
              .limit(1);

          if (res.isNotEmpty) {
            final dbUser = _mapToUserModel(res.first as Map<String, dynamic>);
            
            // Check blockchain_blocks to ensure points and tier are up-to-date
            int expSum = 0;
            try {
              final List blocksRes = await supabase
                  .from('blockchain_blocks')
                  .select('exp_earned')
                  .eq('user_id', dbUser.id);
              if (blocksRes.isNotEmpty) {
                for (final b in blocksRes) {
                  expSum += (b['exp_earned'] as num? ?? 0).toInt();
                }
              }
            } catch (_) {}

            int finalPoints = dbUser.points;
            if (expSum > finalPoints) {
              finalPoints = expSum;
            }
            if (_currentUser != null && _currentUser!.id == dbUser.id && _currentUser!.points > finalPoints) {
              finalPoints = _currentUser!.points;
            }

            _currentUser = dbUser.copyWith(
              points: finalPoints,
              membershipTier: tierFromExp(finalPoints),
            );

            _isLoggedIn = true;
            await _saveSessionToPrefs(_currentUser!);
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Error syncing fresh Supabase profile: $e');
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
        if (_isFallbackAdmin(email, password)) {
          _currentUser = UserModel(
            id: 'admin-dc-001',
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

        if (_isFallbackCashier(email, password)) {
          _currentUser = UserModel(
            id: 'cashier-dc-001',
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

        _errorMessage = _kInvalidCredentialsMsg;
        return false;
      }

      final userId = authRes.user?.id;
      if (userId == null) {
        _errorMessage = 'Login gagal: Tidak ditemukan user';
        return false;
      }

      // 2. Fetch user profile from users table
      final List res = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .limit(1);

      Map<String, dynamic>? data;
      if (res.isNotEmpty) {
        data = res.first as Map<String, dynamic>;
      } else {
        final List byEmail = await supabase
            .from('users')
            .select()
            .eq('email', authRes.user?.email ?? email)
            .limit(1);
        if (byEmail.isNotEmpty) {
          data = byEmail.first as Map<String, dynamic>;
        }
      }

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

        // Check blockchain_blocks in Supabase to restore verified tier and EXP
        try {
          final List blocksRes = await supabase
              .from('blockchain_blocks')
              .select('exp_earned')
              .eq('user_id', _currentUser!.id);
          if (blocksRes.isNotEmpty) {
            int expSum = 0;
            for (final b in blocksRes) {
              expSum += (b['exp_earned'] as num? ?? 0).toInt();
            }
            if (expSum > _currentUser!.points) {
              _currentUser = _currentUser!.copyWith(
                points: expSum,
                membershipTier: tierFromExp(expSum),
              );
            }
          }
        } catch (_) {}
      }

      _isLoggedIn = true;
      await _saveSessionToPrefs(_currentUser!);

      try {
        final prefs = await SharedPreferences.getInstance();
        final walletKey = 'blockchain_wallet_$userId';
        if (!prefs.containsKey(walletKey)) {
          final initialWallet = UserWallet(
            userId: userId,
            userName: _currentUser?.fullName ?? 'User',
            totalExp: _currentUser?.points ?? 0,
            currentTier: MemberTier.fromExp(_currentUser?.points ?? 0),
          );
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
  
  // ============================================
  // BIOMETRIC LOGIN
  // ============================================
  //
  // Aturan:
  // - Tombol biometrik di halaman login hanya untuk akun yang TERAKHIR
  //   login di perangkat ini dan sudah mendaftarkan sidik jari
  //   (lihat BiometricCredentialStore).
  // - Login biometrik TIDAK lagi memulihkan sesi dari JSON profil lokal.
  //   Kredensial akun yang terdaftar dibuka dari secure storage, lalu
  //   login() dipanggil ulang sehingga sesi Supabase asli terbentuk dan
  //   role selalu berasal dari database.
  // - Tidak ada fallback ke last_known_user / cached_active_user.

  /// Verifikasi password akun yang sedang login (dipakai sebelum
  /// mendaftarkan sidik jari). Tidak mengubah state login.
  Future<bool> verifyCurrentPassword(String password) async {
    final user = _currentUser;
    if (user == null || password.isEmpty) return false;
    final email = user.email;

    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.user != null;
    } on AuthException {
      // Akun fallback lokal (tanpa akun Supabase Auth)
      return _isFallbackAdmin(email, password) ||
          _isFallbackCashier(email, password);
    } catch (e) {
      debugPrint('verifyCurrentPassword error: $e');
      return false;
    }
  }

  Future<bool> loginWithBiometrics({String? requiredType}) async {
    final type = requiredType ?? 'fingerprint';
    _errorMessage = null;

    final enrolled = await BiometricCredentialStore.getEnrolledUser();
    if (enrolled == null) {
      _errorMessage =
          'Belum ada akun yang didaftarkan untuk login biometrik pada perangkat ini.';
      notifyListeners();
      return false;
    }

    final enrolledId = enrolled['id']?.toString() ?? '';
    final creds = await BiometricCredentialStore.readCredentials(enrolledId);
    if (creds == null) {
      await BiometricCredentialStore.clear();
      _errorMessage =
          'Data biometrik tidak valid. Silakan login dengan password lalu daftarkan ulang sidik jari.';
      notifyListeners();
      return false;
    }

    // Login ulang lewat jalur normal -> sesi Supabase asli + role dari DB
    final ok = await login(creds.email, creds.password);
    if (!ok) {
      if (_errorMessage == _kInvalidCredentialsMsg) {
        // Password akun sudah berubah -> data biometrik basi
        await BiometricCredentialStore.clearIfOwnedBy(enrolledId);
        _errorMessage =
            'Data biometrik tidak valid. Silakan login dengan password lalu daftarkan ulang sidik jari.';
        notifyListeners();
      }
      return false;
    }

    // Pastikan sidik jari akun ini masih terdaftar (DB, lalu cache lokal).
    // Tidak ada lagi fallback "pasti lolos".
    final userId = _currentUser?.id ?? enrolledId;
    final stillRegistered = await _hasActiveBiometric(userId, type);
    if (!stillRegistered) {
      await logout();
      await BiometricCredentialStore.clearIfOwnedBy(enrolledId);
      _errorMessage =
          'Sidik jari untuk akun ini sudah tidak terdaftar. Silakan daftarkan ulang di menu Keamanan & Privasi.';
      notifyListeners();
      return false;
    }

    try {
      await supabase
          .from('user_biometrics')
          .update({'last_used_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .eq('biometric_type', type);
    } catch (_) {}

    return true;
  }

  Future<bool> _hasActiveBiometric(String userId, String type) async {
    if (userId.isEmpty) return false;

    try {
      final List bioRes = await supabase
          .from('user_biometrics')
          .select('id')
          .eq('user_id', userId)
          .eq('biometric_type', type)
          .eq('is_active', true)
          .limit(1);
      if (bioRes.isNotEmpty) return true;
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBioJson = prefs.getString('biometrics_list_$userId');
      if (cachedBioJson != null) {
        final List list = jsonDecode(cachedBioJson);
        return list.any(
          (b) => b['biometric_type'] == type && b['is_active'] != false,
        );
      }
    } catch (_) {}

    return false;
  }

  /// Nama akun yang terdaftar biometrik di perangkat ini.
  /// Null jika tidak ada (login screen harus menyembunyikan tombol fingerprint).
  Future<String?> getBiometricEnrolledUserName() async {
    final enrolled = await BiometricCredentialStore.getEnrolledUser();
    if (enrolled == null) return null;
    final name = enrolled['full_name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    final email = enrolled['email']?.toString() ?? '';
    return email.isNotEmpty ? email : null;
  }

  /// Hapus pendaftaran biometrik akun yang sedang ditampilkan di halaman login.
  Future<void> clearBiometricUser() async {
    await BiometricCredentialStore.clear();
    notifyListeners();
  }

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
        
        // Also persist genesis block to Supabase blockchain_blocks table
        try {
          final genesisBlock = initialWallet.blockchain.first;
          await supabase.from('blockchain_blocks').insert(genesisBlock.toDbMap(userId));
        } catch (e) {
          debugPrint('Notice inserting genesis block to DB on register: $e');
        }
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

  /// Ensures Admin and Cashier accounts are ready.
  Future<void> ensureAdminAccount() async {
    try {
      // 1. Check if admin exists in Supabase Auth
      try {
        await supabase.auth.signUp(
          email: 'admin@doctorcomputer.id',
          password: 'Admin@DC2026!',
        );
      } catch (_) {}

      // 2. Check if cashier exists in Supabase Auth
      try {
        await supabase.auth.signUp(
          email: 'cashier@doctorcomputer.id',
          password: 'Cashier@DC2026!',
        );
      } catch (_) {}

      // 3. Make sure admin row exists in users table
      final List adminCheck = await supabase
          .from('users')
          .select('id')
          .eq('email', 'admin@doctorcomputer.id')
          .limit(1);

      if (adminCheck.isEmpty) {
        await supabase.from('users').insert({
          'id': 'admin-dc-001',
          'full_name': 'Administrator',
          'email': 'admin@doctorcomputer.id',
          'phone': '081234567890',
          'address': 'Doctor Computer HQ',
          'city': 'Jakarta',
          'membership_tier': 'platinum',
          'points': 99999,
          'join_date': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('ensureAdminAccount notice: $e');
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
      await prefs.remove('last_known_user'); // sisa versi lama
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
    return UserModel.fromMap(data);
  }

  UserRole _parseUserRole(dynamic role, {String? email}) {
    if (email != null) {
      final lowerEmail = email.toLowerCase();
      if (lowerEmail == 'admin@doctorcomputer.id' || lowerEmail == 'admin') {
        return UserRole.admin;
      }
      if (lowerEmail == 'cashier@doctorcomputer.id' || lowerEmail == 'cashier') {
        return UserRole.cashier;
      }
    }
    if (role == null) return UserRole.user;
    if (role is String) {
      switch (role.toLowerCase()) {
        case 'admin':
          return UserRole.admin;
        case 'cashier':
          return UserRole.cashier;
        case 'user':
        default:
          return UserRole.user;
      }
    }
    return UserRole.user;
  }

  MembershipTier parseMembershipTier(String? tierName) {
    if (tierName == null) return MembershipTier.bronze;
    switch (tierName.toLowerCase()) {
      case 'silver': return MembershipTier.silver;
      case 'gold': return MembershipTier.gold;
      case 'platinum': return MembershipTier.platinum;
      default: return MembershipTier.bronze;
    }
  }

  MembershipTier tierFromExp(int exp) {
    if (exp >= 1200) return MembershipTier.platinum;
    if (exp >= 600) return MembershipTier.gold;
    if (exp >= 300) return MembershipTier.silver;
    return MembershipTier.bronze;
  }

  /// Updates user points and tier in local state, local cache, and syncs to Supabase users table
  Future<void> updatePointsAndTier(int newPoints, MembershipTier newTier) async {
    if (_currentUser == null) return;
    if (_currentUser!.points == newPoints && _currentUser!.membershipTier == newTier) return;

    _currentUser = _currentUser?.copyWith(
      points: newPoints,
      membershipTier: newTier,
    );
    notifyListeners();

    if (_currentUser != null) {
      await _saveSessionToPrefs(_currentUser!);

      try {
        await supabase.from('users').update({
          'points': newPoints,
          'membership_tier': newTier.name,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentUser!.id);
        debugPrint('[AuthProvider] Synced points ($newPoints) & tier (${newTier.name}) to Supabase users table.');
      } catch (e) {
        debugPrint('Notice updating user points in users table: $e');
      }
    }
  }

}
