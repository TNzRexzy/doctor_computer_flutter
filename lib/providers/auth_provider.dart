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
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Login via Supabase Auth
      final authRes = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Kalau tidak throw exception, berarti berhasil
      final userId = authRes.user?.id;
      if (userId == null) {
        _errorMessage = 'Login failed: No user found';
        debugPrint('Login: user ID null');
        return false;
      }

      // 2. Fetch user profile dari tabel users
      final data = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      _currentUser = _mapToUserModel(data);
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

    } on AuthException catch (e) {
      // Error autentikasi (email/password salah, dll)
      _errorMessage = e.message;
      debugPrint('Login AuthException: ${e.message}');
      return false;
    } on PostgrestException catch (e) {
      // Error query database
      _errorMessage = e.message;
      debugPrint('Login PostgrestException: ${e.message}');
      return false;
    } catch (e) {
      // Error umum (network, dll)
      _errorMessage = 'Network error';
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
        _errorMessage = 'Registrasi gagal: Tidak ada user ID';
        debugPrint('Register: user ID null');
        return false;
      }

      // 2. Insert user profile ke tabel users
      final profileData = await supabase
          .from('users')
          .insert({
            'id': userId,
            'full_name': name,
            'email': email,
            'phone': phone,
            'address': '',
            'city': '',
            'membership_tier': 'bronze',
            'points': 0,
            'join_date': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      _currentUser = _mapToUserModel(profileData);
      _isLoggedIn = true;

      // Blok 0: Genesis Block dibuat pada pengguna baru daftar akun
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
      _errorMessage = e.message;
      debugPrint('Register AuthException: ${e.message}');
      debugPrint('Register AuthException code: ${e.statusCode}');
      return false;
    } on PostgrestException catch (e) {
      _errorMessage = e.message;
      debugPrint('Register PostgrestException: ${e.message}');
      debugPrint('Register PostgrestException code: ${e.code}');
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
    String city,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUserId = currentUser?.id;
      if (currentUserId == null) {
        _errorMessage = 'Update gagal: Tidak ada current user';
        debugPrint('Update: no current user');
        return false;
      }

      final data = await supabase
          .from('users')
          .update({
            'full_name': name,
            'phone': phone,
            'address': address,
            'city': city,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', currentUserId)
          .select()
          .single();

      _currentUser = _mapToUserModel(data);
      return true;

    } on PostgrestException catch (e) {
      _errorMessage = e.message;
      debugPrint('Update PostgrestException: ${e.message}');
      return false;
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
  // LOGOUT
  // ============================================
  Future<bool> logout() async {
    try {
      await supabase.auth.signOut();
      _currentUser = null;
      _isLoggedIn = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      debugPrint('Logout AuthException: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Logout exception: $e');
      return false;
    }
  }

  // ============================================
  // HELPER: Map response ke UserModel
  // ============================================
  UserModel _mapToUserModel(Map<String, dynamic> data) {
    return UserModel(
      id: data['id'] as String,
      fullName: data['full_name'] as String,
      email: data['email'] as String,
      phone: (data['phone'] as String? ?? '').toString(),
      address: (data['address'] as String? ?? '').toString(),
      city: (data['city'] as String? ?? '').toString(),
      membershipTier: _parseMembershipTier(data['membership_tier']),
      points: (data['points'] as num? ?? 0).toInt(),
      joinDate: _parseDateTime(data['join_date']),
    );
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