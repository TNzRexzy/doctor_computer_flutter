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
          notifyListeners();
          return true;
        }

        _errorMessage = 'Email atau password salah';
        return false;
      }

      final userId = authRes.user?.id;
      if (userId == null) {
        _errorMessage = 'Login gagal: Tidak ditemukan user';
        return false;
      }

      // 2. Fetch user profile dari tabel users using .limit(1) to avoid "Cannot coerce" error
      final List res = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .limit(1);

      Map<String, dynamic>? data = res.isNotEmpty ? res.first as Map<String, dynamic> : null;

      if (data == null) {
        // Try searching by email
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
      }

      _isLoggedIn = true;

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
      // Standard columns that always exist in users table
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

      // Every registered user automatically receives UserRole.user (biasa)
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
        debugPrint('Notice updating profile: $e');
      }

      // Update local state
      _currentUser = _currentUser?.copyWith(
        fullName: name,
        phone: phone,
        address: address,
        city: city,
        latitude: latitude ?? _currentUser?.latitude,
        longitude: longitude ?? _currentUser?.longitude,
        profileImageUrl: profileImageUrl ?? _currentUser?.profileImageUrl,
      );

      return true;

    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Update exception: $e');
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
      _currentUser = null;
      _isLoggedIn = false;
      notifyListeners();
      return true;
    } catch (e) {
      _currentUser = null;
      _isLoggedIn = false;
      notifyListeners();
      return true;
    }
  }

  // ============================================
  // HELPER: Map response ke UserModel
  // ============================================
  UserModel _mapToUserModel(Map<String, dynamic> data) {
    final email = data['email']?.toString() ?? '';
    return UserModel(
      id: data['id']?.toString() ?? '',
      fullName: data['full_name']?.toString() ?? '',
      email: email,
      phone: data['phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      membershipTier: _parseMembershipTier(data['membership_tier']),
      points: (data['points'] as num? ?? 0).toInt(),
      joinDate: _parseDateTime(data['join_date']),
      role: _parseUserRole(data['role'], email: email),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      profileImageUrl: data['profile_image_url']?.toString(),
    );
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

  MembershipTier _parseMembershipTier(dynamic tier) {
    if (tier == null) return MembershipTier.bronze;
    if (tier is String) {
      switch (tier.toLowerCase()) {
        case 'bronze': return MembershipTier.bronze;
        case 'silver': return MembershipTier.silver;
        case 'gold':   return MembershipTier.gold;
        case 'platinum': return MembershipTier.platinum;
        default: return MembershipTier.bronze;
      }
    }
    if (tier is num) {
      switch (tier.toInt()) {
        case 1: return MembershipTier.bronze;
        case 2: return MembershipTier.silver;
        case 3: return MembershipTier.gold;
        case 4: return MembershipTier.platinum;
        default: return MembershipTier.bronze;
      }
    }
    return MembershipTier.bronze;
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}