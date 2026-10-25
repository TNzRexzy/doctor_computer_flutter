import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';
import 'package:doctor_computer/services/biometric_service.dart';
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

  AuthProvider();

  // ============================================
  // SESSION PERSISTENCE & RESTORATION
  // ============================================
  Future<void> _saveSessionToPrefs(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_active_user', jsonEncode(user.toMap()));
      await prefs.setBool('is_logged_in', true);
    } catch (e) {
      debugPrint('Error caching user session: $e');
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
  Future<Map<String, dynamic>?> _fetchProfileRow({
    String? id,
    String? email,
  }) async {
    if (id == null && email == null) return null;

    try {
      var query = supabase.from('users').select();
      query = id != null ? query.eq('id', id) : query.eq('email', email!);

      final rows = await query.limit(1);
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first as Map);
    } on PostgrestException catch (e) {
      debugPrint(
        '[AuthProvider] profile lookup failed (${e.code}): ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('[AuthProvider] profile lookup failed: $e');
      return null;
    }
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final supaUser = supabase.auth.currentUser;
      if (supaUser == null) {
        await prefs.remove('cached_active_user');
        await prefs.setBool('is_logged_in', false);
        return;
      }

      final data = await _fetchProfileRow(id: supaUser.id);
      if (data == null) {
        await supabase.auth.signOut();
        await prefs.remove('cached_active_user');
        await prefs.setBool('is_logged_in', false);
        return;
      }

      _currentUser = _mapToUserModel(data);
      _isLoggedIn = true;
      await _saveSessionToPrefs(_currentUser!);
      await BiometricService.instance.rememberLastUser(_currentUser!.id);
      notifyListeners();
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
      final authRes = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = authRes.user?.id;
      if (userId == null) {
        _errorMessage = 'Login gagal: Tidak ditemukan user';
        return false;
      }

      // 2. Fetch user profile from users table: id first, then email alias.
      //    Both reads are list-based (see _fetchProfileRow) so duplicate rows
      //    can no longer trigger a PostgREST coercion failure during login.
      final data =
          await _fetchProfileRow(id: userId) ??
          await _fetchProfileRow(email: authRes.user?.email ?? email);

      if (data == null) {
        await supabase.auth.signOut();
        _errorMessage =
            'Profil akun tidak ditemukan. Silakan hubungi administrator.';
        return false;
      }

      _currentUser = _mapToUserModel(data);
      _isLoggedIn = true;
      await _saveSessionToPrefs(_currentUser!);
      await BiometricService.instance.rememberLastUser(userId);

      try {
        final prefs = await SharedPreferences.getInstance();
        final walletKey = 'blockchain_wallet_$userId';
        if (!prefs.containsKey(walletKey)) {
          final initialWallet = UserWallet(
            userId: userId,
            userName: _currentUser?.fullName ?? 'User',
          );
          await prefs.setString(walletKey, jsonEncode(initialWallet.toMap()));
        }
      } catch (e) {
        debugPrint('Error verifying genesis block on login: $e');
      }

      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      debugPrint('Login AuthException: ${e.message}');
      return false;
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
  // LOGIN DENGAN SIDIK JARI
  // ============================================
  /// Login memakai sidik jari yang didaftarkan di perangkat ini untuk akun
  /// yang terakhir login. Return `false` tanpa pesan error jika pengguna
  /// hanya membatalkan prompt sidik jari.
  Future<bool> loginWithBiometric() async {
    final bio = BiometricService.instance;
    _errorMessage = null;

    final credential = await bio.lastUserCredential();
    if (credential == null) {
      _errorMessage = 'Sidik jari belum didaftarkan di perangkat ini.';
      notifyListeners();
      return false;
    }

    try {
      final scanned = await bio.authenticate('Pindai sidik jari untuk masuk');
      if (!scanned) return false;
    } on BiometricException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }

    final success = await login(credential.email, credential.password);
    if (!success) {
      final message = (_errorMessage ?? '').toLowerCase();
      if (message.contains('invalid login credentials')) {
        // Password akun sudah berubah: kredensial tersimpan tidak berlaku lagi.
        await bio.deleteCredential(credential.userId);
        _errorMessage =
            'Password akun sudah berubah. Masuk dengan password, lalu '
            'daftarkan ulang sidik jari.';
      }
      notifyListeners();
      return false;
    }

    try {
      final stillActive = _currentUser?.id == credential.userId &&
          await bio.verifyRegistration(credential.userId, credential.token);
      if (!stillActive) {
        await bio.deleteCredential(credential.userId);
        await logout();
        _errorMessage =
            'Sidik jari ini sudah dihapus dari akun. Masuk dengan password.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('loginWithBiometric verify error: $e');
      await logout();
      _errorMessage = 'Gagal memverifikasi sidik jari. Periksa koneksi Anda.';
      notifyListeners();
      return false;
    }

    return true;
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
        data: {'full_name': name, 'phone': phone},
      );

      final userId = authRes.user?.id;
      if (userId == null) {
        _errorMessage = 'Registrasi gagal: Tidak ada respon user ID';
        return false;
      }

      if (authRes.session != null) {
        final profile = await _fetchProfileRow(id: userId);
        if (profile == null) {
          await supabase.auth.signOut();
          _errorMessage = 'Registrasi berhasil, tetapi profil belum tersedia. Silakan login kembali.';
          return false;
        }
        _currentUser = _mapToUserModel(profile);
        _isLoggedIn = true;
        await _saveSessionToPrefs(_currentUser!);

        final prefs = await SharedPreferences.getInstance();
        final walletKey = 'blockchain_wallet_$userId';
        if (!prefs.containsKey(walletKey)) {
          final initialWallet = UserWallet(userId: userId, userName: name);
          await prefs.setString(walletKey, jsonEncode(initialWallet.toMap()));
        }
      }

      return true;
    } on AuthException catch (e) {
      if (e.statusCode == '422' ||
          e.message.toLowerCase().contains('already registered')) {
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
      if (profileImageUrl != null) {
        updates['profile_image_url'] = profileImageUrl;
      }

      await supabase
          .from('users')
          .update(updates)
          .eq('id', currentUserId)
          .select()
          .single();

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

      await supabase
          .from('users')
          .update({
            'profile_image_url': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', currentUserId)
          .select()
          .single();

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

      await supabase
          .from('users')
          .update({
            'latitude': lat,
            'longitude': lng,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', currentUserId)
          .select()
          .single();

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

  Future<bool> updateUserAsAdmin(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final result = await supabase.rpc(
        'admin_update_user',
        params: {
          'p_user_id': userId,
          'p_full_name': updates['full_name']?.toString() ?? '',
          'p_points': (updates['points'] as num?)?.toInt() ?? 0,
          'p_role': updates['role']?.toString() ?? 'client',
          'p_membership_tier':
              updates['membership_tier']?.toString() ?? 'bronze',
        },
      );
      return result is Map;
    } catch (e) {
      debugPrint('Admin update error: $e');
      return false;
    }
  }

  // ============================================
  // LOGOUT
  // ============================================
  Future<bool> logout() async {
    final loggingOutUserId = _currentUser?.id;
    if (loggingOutUserId != null) {
      // Tombol login sidik jari hanya muncul untuk akun yang terakhir keluar.
      await BiometricService.instance.rememberLastUser(loggingOutUserId);
    }

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
    return UserModel.fromMap(data);
  }
}
