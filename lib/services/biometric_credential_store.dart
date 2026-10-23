import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/data/models/user_model.dart';

/// Menyimpan akun yang terdaftar untuk login biometrik di perangkat ini.
///
/// Aturan:
/// - Satu perangkat boleh menyimpan BEBERAPA akun biometrik (per user).
/// - Tombol login biometrik di halaman login HANYA untuk akun yang
///   TERAKHIR login di perangkat ini (`last_login_user_id`), dan hanya jika
///   akun itu memang sudah mendaftarkan sidik jari. Jadi kalau akun terakhir
///   adalah user biasa tanpa sidik jari, tombol tidak tampil.
/// - Penanda akun (id, nama, email) ada di SharedPreferences. Role TIDAK
///   disimpan dan tidak pernah dipercaya dari sini.
/// - Email & password disimpan terenkripsi di secure storage
///   (Keystore/Keychain) dengan key per user.
class BiometricCredentialStore {
  BiometricCredentialStore._();

  static const String _accountsKey = 'biometric_accounts'; // JSON: id -> info
  static const String _legacySingleKey = 'saved_biometric_user'; // versi lama
  static const String _lastUserKey = 'last_login_user_id';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static String _emailKey(String userId) => 'bio_email_$userId';
  static String _passKey(String userId) => 'bio_pass_$userId';

  // ------------------------------------------------------------
  // Akun terakhir yang login
  // ------------------------------------------------------------

  /// Dipanggil setiap kali sesi login berhasil dibuat / dipulihkan.
  static Future<void> setLastLoginUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUserKey, userId);
    } catch (e) {
      debugPrint('[BiometricCredentialStore] setLastLoginUser error: $e');
    }
  }

  // ------------------------------------------------------------
  // Pendaftaran
  // ------------------------------------------------------------

  /// Daftarkan akun untuk biometrik di perangkat ini.
  /// Password HARUS sudah diverifikasi oleh pemanggil.
  static Future<void> enrollAccount({
    required UserModel user,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadAccounts(prefs);

    await _secure.write(key: _emailKey(user.id), value: user.email);
    await _secure.write(key: _passKey(user.id), value: password);

    accounts[user.id] = {
      'id': user.id,
      'full_name': user.fullName,
      'email': user.email,
    };
    await _saveAccounts(prefs, accounts);
    await prefs.setString(_lastUserKey, user.id);
  }

  // ------------------------------------------------------------
  // Pembacaan
  // ------------------------------------------------------------

  /// Akun yang boleh memakai tombol biometrik di halaman login:
  /// akun yang terakhir login DAN punya kredensial biometrik. Selain itu null.
  static Future<Map<String, dynamic>?> getEnrolledUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_lastUserKey);
      if (lastId == null || lastId.isEmpty) return null;

      final accounts = _loadAccounts(prefs);
      final info = accounts[lastId];
      if (info == null) return null;

      final creds = await readCredentials(lastId);
      if (creds == null) {
        // Data basi (kredensial hilang) -> bersihkan
        accounts.remove(lastId);
        await _saveAccounts(prefs, accounts);
        return null;
      }
      return Map<String, dynamic>.from(info as Map);
    } catch (e) {
      debugPrint('[BiometricCredentialStore] getEnrolledUser error: $e');
      return null;
    }
  }

  /// Email & password tersimpan untuk user ini, atau null jika tidak ada.
  static Future<({String email, String password})?> readCredentials(
    String userId,
  ) async {
    try {
      final email = await _secure.read(key: _emailKey(userId));
      final pass = await _secure.read(key: _passKey(userId));
      if (email == null || email.isEmpty || pass == null || pass.isEmpty) {
        return null;
      }
      return (email: email, password: pass);
    } catch (e) {
      debugPrint('[BiometricCredentialStore] readCredentials error: $e');
      return null;
    }
  }

  // ------------------------------------------------------------
  // Penghapusan
  // ------------------------------------------------------------

  /// Hapus pendaftaran biometrik akun yang sedang ditampilkan di halaman
  /// login (akun yang terakhir login).
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_lastUserKey);
      if (lastId != null && lastId.isNotEmpty) {
        await _removeAccount(prefs, lastId);
      }
    } catch (e) {
      debugPrint('[BiometricCredentialStore] clear error: $e');
    }
  }

  /// Hapus pendaftaran biometrik milik [userId] saja (akun lain tidak disentuh).
  static Future<void> clearIfOwnedBy(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _removeAccount(prefs, userId);
    } catch (e) {
      debugPrint('[BiometricCredentialStore] clearIfOwnedBy error: $e');
    }
  }

  // ------------------------------------------------------------
  // Internal
  // ------------------------------------------------------------

  static Future<void> _removeAccount(SharedPreferences prefs, String userId) async {
    final accounts = _loadAccounts(prefs);
    accounts.remove(userId);
    await _saveAccounts(prefs, accounts);
    try {
      await _secure.delete(key: _emailKey(userId));
      await _secure.delete(key: _passKey(userId));
    } catch (e) {
      debugPrint('[BiometricCredentialStore] delete secrets error: $e');
    }
  }

  /// Muat daftar akun. Sekaligus memigrasikan slot tunggal versi lama
  /// (`saved_biometric_user`) ke daftar baru.
  static Map<String, dynamic> _loadAccounts(SharedPreferences prefs) {
    Map<String, dynamic> accounts = {};
    try {
      final raw = prefs.getString(_accountsKey);
      if (raw != null && raw.isNotEmpty) {
        accounts = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {
      accounts = {};
    }

    final legacy = prefs.getString(_legacySingleKey);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        final map = jsonDecode(legacy) as Map<String, dynamic>;
        final id = map['id']?.toString() ?? '';
        if (id.isNotEmpty && !accounts.containsKey(id)) {
          accounts[id] = {
            'id': id,
            'full_name': map['full_name']?.toString() ?? '',
            'email': map['email']?.toString() ?? '',
          };
          // simpan hasil migrasi (tanpa menunggu)
          prefs.setString(_accountsKey, jsonEncode(accounts));
        }
      } catch (_) {}
      prefs.remove(_legacySingleKey);
    }
    return accounts;
  }

  static Future<void> _saveAccounts(
    SharedPreferences prefs,
    Map<String, dynamic> accounts,
  ) async {
    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }
}
