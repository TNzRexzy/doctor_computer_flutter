import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kondisi sensor sidik jari di perangkat ini.
enum BiometricStatus {
  /// Platform tidak didukung (web / desktop).
  unsupportedPlatform,

  /// Perangkat tidak punya sensor biometrik.
  notAvailable,

  /// Ada sensor, tetapi belum ada sidik jari yang terdaftar di pengaturan HP.
  notEnrolled,

  /// Siap dipakai.
  ready,
}

/// Error yang pesannya aman ditampilkan langsung ke pengguna.
class BiometricException implements Exception {
  final String message;
  const BiometricException(this.message);

  @override
  String toString() => message;
}

/// Kredensial login yang tersimpan terenkripsi di perangkat ini.
class BiometricCredential {
  final String userId;
  final String email;
  final String password;

  /// ID unik pendaftaran sidik jari ini (sama dengan
  /// `user_biometrics.biometric_token` di database).
  final String token;

  const BiometricCredential({
    required this.userId,
    required this.email,
    required this.password,
    required this.token,
  });

  String toJson() => jsonEncode({
    'user_id': userId,
    'email': email,
    'password': password,
    'token': token,
  });

  static BiometricCredential? fromJson(String source) {
    final map = jsonDecode(source);
    if (map is! Map) return null;
    final userId = map['user_id']?.toString();
    final email = map['email']?.toString();
    final password = map['password']?.toString();
    final token = map['token']?.toString();
    if (userId == null || email == null || password == null || token == null) {
      return null;
    }
    return BiometricCredential(
      userId: userId,
      email: email,
      password: password,
      token: token,
    );
  }
}

/// Login & pendaftaran sidik jari.
///
/// Cara kerja:
///  * Saat mendaftar, pengguna memindai sidik jari (BiometricPrompt Android,
///    `biometricOnly` = hanya biometrik kuat, bukan PIN/pola) dan memasukkan
///    password. Email + password disimpan di penyimpanan terenkripsi
///    (Android Keystore) dan satu baris dicatat di `public.user_biometrics`.
///  * Setelah logout, tombol "Masuk dengan Sidik Jari" muncul hanya jika akun
///    terakhir yang login punya kredensial tersimpan di perangkat ini.
///  * Saat login, sidik jari dipindai lagi lalu kredensial dipakai untuk
///    login normal ke Supabase. Pendaftaran harus masih aktif di database
///    (bisa dicabut dari perangkat lain).
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  static const String _lastUserKey = 'bio_last_user_id';
  static const String _credentialPrefix = 'bio_cred_';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _platformName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  // ============================================================
  // SENSOR
  // ============================================================

  Future<BiometricStatus> checkStatus() async {
    if (!_platformSupported) return BiometricStatus.unsupportedPlatform;
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return BiometricStatus.notAvailable;

      final enrolled = await _localAuth.getAvailableBiometrics();
      if (enrolled.isEmpty) return BiometricStatus.notEnrolled;
      return BiometricStatus.ready;
    } on PlatformException catch (e) {
      debugPrint('[Biometric] status error: ${e.code} ${e.message}');
      return BiometricStatus.notAvailable;
    } catch (e) {
      debugPrint('[Biometric] status error: $e');
      return BiometricStatus.notAvailable;
    }
  }

  String statusMessage(BiometricStatus status) {
    switch (status) {
      case BiometricStatus.unsupportedPlatform:
        return 'Sidik jari hanya tersedia di aplikasi Android/iOS.';
      case BiometricStatus.notAvailable:
        return 'Perangkat ini tidak memiliki sensor sidik jari.';
      case BiometricStatus.notEnrolled:
        return 'Belum ada sidik jari di perangkat. Daftarkan dulu di '
            'Pengaturan HP > Keamanan > Sidik jari.';
      case BiometricStatus.ready:
        return 'Sensor sidik jari siap digunakan.';
    }
  }

  /// Menampilkan prompt sidik jari bawaan sistem.
  ///
  /// Return `true` jika sidik jari cocok, `false` jika dibatalkan pengguna.
  /// Melempar [BiometricException] untuk kegagalan lain (terkunci, dll).
  Future<bool> authenticate(String reason) async {
    if (!_platformSupported) {
      throw BiometricException(
        statusMessage(BiometricStatus.unsupportedPlatform),
      );
    }
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Hanya biometrik kuat (sidik jari). PIN/pola/password HP ditolak.
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      debugPrint('[Biometric] authenticate error: ${e.code} ${e.message}');
      if (code.contains('permanentlylockedout')) {
        throw const BiometricException(
          'Sensor sidik jari terkunci. Buka kunci HP dengan PIN/pola dulu, '
          'lalu coba lagi.',
        );
      }
      if (code.contains('lockedout')) {
        throw const BiometricException(
          'Terlalu banyak percobaan. Coba lagi beberapa saat.',
        );
      }
      if (code.contains('notenrolled')) {
        throw BiometricException(statusMessage(BiometricStatus.notEnrolled));
      }
      if (code.contains('notavailable') ||
          code.contains('biometriconlynotsupported')) {
        throw BiometricException(statusMessage(BiometricStatus.notAvailable));
      }
      throw const BiometricException('Verifikasi sidik jari gagal.');
    }
  }

  // ============================================================
  // PENYIMPANAN LOKAL (terenkripsi)
  // ============================================================

  Future<void> rememberLastUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUserKey, userId);
    } catch (e) {
      debugPrint('[Biometric] rememberLastUser error: $e');
    }
  }

  Future<BiometricCredential?> readCredential(String userId) async {
    try {
      final raw = await _storage.read(key: '$_credentialPrefix$userId');
      if (raw == null || raw.isEmpty) return null;
      final credential = BiometricCredential.fromJson(raw);
      if (credential == null) {
        await deleteCredential(userId);
      }
      return credential;
    } catch (e) {
      // Data terenkripsi rusak (mis. hasil restore backup di HP lain).
      debugPrint('[Biometric] readCredential error: $e');
      await deleteCredential(userId);
      return null;
    }
  }

  /// Kredensial milik akun yang terakhir login di perangkat ini.
  /// `null` jika akun tersebut belum mendaftarkan sidik jari di sini.
  Future<BiometricCredential?> lastUserCredential() async {
    if (!_platformSupported) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_lastUserKey);
      if (userId == null || userId.isEmpty) return null;
      return readCredential(userId);
    } catch (e) {
      debugPrint('[Biometric] lastUserCredential error: $e');
      return null;
    }
  }

  Future<void> deleteCredential(String userId) async {
    try {
      await _storage.delete(key: '$_credentialPrefix$userId');
    } catch (e) {
      debugPrint('[Biometric] deleteCredential error: $e');
    }
  }

  // ============================================================
  // DATABASE (public.user_biometrics)
  // ============================================================

  /// Daftar sidik jari aktif milik [userId] (semua perangkat).
  Future<List<Map<String, dynamic>>> fetchRegistrations(String userId) async {
    final rows = await _supabase
        .from('user_biometrics')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Mendaftarkan sidik jari untuk akun yang sedang login.
  ///
  /// Urutan: pindai sidik jari -> verifikasi password -> catat di database ->
  /// simpan kredensial terenkripsi. Jika langkah akhir gagal, catatan di
  /// database dibatalkan.
  Future<void> registerFingerprint({
    required String userId,
    required String email,
    required String password,
  }) async {
    final status = await checkStatus();
    if (status != BiometricStatus.ready) {
      throw BiometricException(statusMessage(status));
    }

    final scanned = await authenticate(
      'Pindai sidik jari untuk mendaftarkannya',
    );
    if (!scanned) {
      throw const BiometricException('Pendaftaran sidik jari dibatalkan.');
    }

    // Pastikan password benar sebelum disimpan.
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user?.id != userId) {
        throw const BiometricException('Akun tidak cocok. Coba login ulang.');
      }
    } on AuthException {
      throw const BiometricException('Password salah.');
    }

    final token = _generateToken();
    String? rowId;
    try {
      final inserted = await _supabase
          .from('user_biometrics')
          .insert({
            'user_id': userId,
            'biometric_type': 'fingerprint',
            'credential_name': 'Sidik jari ($_platformName)',
            'device_model': _platformName,
            'biometric_token': token,
            'is_active': true,
          })
          .select('id')
          .single();
      rowId = inserted['id']?.toString();

      await _storage.write(
        key: '$_credentialPrefix$userId',
        value: BiometricCredential(
          userId: userId,
          email: email,
          password: password,
          token: token,
        ).toJson(),
      );
    } on PostgrestException catch (e) {
      debugPrint('[Biometric] register DB error: ${e.code} ${e.message}');
      throw const BiometricException(
        'Gagal menyimpan sidik jari ke database. Coba lagi.',
      );
    } catch (e) {
      debugPrint('[Biometric] register error: $e');
      if (rowId != null) {
        try {
          await _supabase.from('user_biometrics').delete().eq('id', rowId);
        } catch (_) {}
      }
      throw const BiometricException('Gagal menyimpan sidik jari di perangkat.');
    }

    await rememberLastUser(userId);
    await _syncSecuritySetting(userId);
  }

  /// Menghapus satu pendaftaran sidik jari. Jika itu milik perangkat ini,
  /// kredensial lokal ikut dihapus.
  Future<void> removeRegistration({
    required String userId,
    required String rowId,
    required String token,
  }) async {
    try {
      await _supabase
          .from('user_biometrics')
          .delete()
          .eq('id', rowId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      debugPrint('[Biometric] remove error: ${e.code} ${e.message}');
      throw const BiometricException('Gagal menghapus sidik jari.');
    }

    final local = await readCredential(userId);
    if (local != null && local.token == token) {
      await deleteCredential(userId);
    }
    await _syncSecuritySetting(userId);
  }

  /// Dipanggil setelah login dengan sidik jari: memastikan pendaftaran ini
  /// masih aktif di database, lalu mencatat `last_used_at`.
  /// Melempar exception jika database tidak dapat dihubungi (fail closed).
  Future<bool> verifyRegistration(String userId, String token) async {
    final rows = await _supabase
        .from('user_biometrics')
        .select('id')
        .eq('user_id', userId)
        .eq('biometric_token', token)
        .eq('is_active', true)
        .limit(1);
    if (rows.isEmpty) return false;

    try {
      await _supabase
          .from('user_biometrics')
          .update({'last_used_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', rows.first['id']);
    } catch (e) {
      debugPrint('[Biometric] last_used_at update failed: $e');
    }
    return true;
  }

  /// Menyelaraskan `user_security_settings.biometric_enabled` dengan jumlah
  /// pendaftaran aktif. Best-effort: kegagalan tidak membatalkan apa pun.
  Future<void> _syncSecuritySetting(String userId) async {
    try {
      final active = await fetchRegistrations(userId);
      await _supabase.from('user_security_settings').upsert({
        'user_id': userId,
        'biometric_enabled': active.isNotEmpty,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('[Biometric] security setting sync failed: $e');
    }
  }

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
