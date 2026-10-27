import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:doctor_computer/data/models/user_model.dart';

class OfflineAuthService {
  OfflineAuthService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const int _formatVersion = 1;
  static const int _iterations = 600000;
  static const int _credentialLifetimeDays = 14;
  static const int _saltLength = 16;
  static const int _derivedKeyBits = 256;
  static const String _keyPrefix = 'offline_auth_v1_';
  static final Pbkdf2 _kdf = Pbkdf2.hmacSha256(
    iterations: _iterations,
    bits: _derivedKeyBits,
  );

  final FlutterSecureStorage _storage;

  bool get isSupported => !kIsWeb;

  Future<void> cachePasswordCredential({
    required UserModel user,
    required String password,
  }) async {
    if (!isSupported) return;
    if (!_isEligibleRole(user.role)) {
      await removeCredential(user.email);
      return;
    }

    final normalizedEmail = _normalizeEmail(user.email);
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw ArgumentError('Email dan password tidak boleh kosong.');
    }

    final salt = List<int>.generate(
      _saltLength,
      (_) => Random.secure().nextInt(256),
    );
    final passwordHash = await _derivePasswordHash(password, salt);
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'version': _formatVersion,
      'email': normalizedEmail,
      'user': {
        'id': user.id,
        'full_name': user.fullName,
        'email': normalizedEmail,
        'role': user.role.name,
      },
      'password_hash': base64Encode(passwordHash),
      'salt': base64Encode(salt),
      'kdf': 'pbkdf2_hmac_sha256',
      'iterations': _iterations,
      'verified_at': now.toIso8601String(),
      'expires_at': now
          .add(const Duration(days: _credentialLifetimeDays))
          .toIso8601String(),
    };

    await _storage.write(
      key: _credentialKey(normalizedEmail),
      value: jsonEncode(payload),
    );
  }

  Future<UserModel?> authenticateOffline({
    required String email,
    required String password,
  }) async {
    if (!isSupported) return null;

    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty || password.isEmpty) return null;

    final encoded = await _storage.read(key: _credentialKey(normalizedEmail));
    if (encoded == null) return null;

    try {
      final payload = jsonDecode(encoded);
      if (payload is! Map<String, dynamic> ||
          payload['version'] != _formatVersion ||
          payload['email'] != normalizedEmail ||
          payload['kdf'] != 'pbkdf2_hmac_sha256' ||
          payload['iterations'] != _iterations) {
        return null;
      }

      final expiresAt = DateTime.tryParse(
        payload['expires_at']?.toString() ?? '',
      );
      if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
        await removeCredential(normalizedEmail);
        return null;
      }

      final encodedSalt = payload['salt'];
      final encodedHash = payload['password_hash'];
      final userMap = payload['user'];
      if (encodedSalt is! String ||
          encodedHash is! String ||
          userMap is! Map<String, dynamic>) {
        return null;
      }

      final user = UserModel.fromMap(userMap);
      if (!_isEligibleRole(user.role) ||
          user.id.isEmpty ||
          _normalizeEmail(user.email) != normalizedEmail) {
        return null;
      }

      final expectedHash = base64Decode(encodedHash);
      final actualHash = await _derivePasswordHash(
        password,
        base64Decode(encodedSalt),
      );
      if (!_constantTimeEquals(actualHash, expectedHash)) return null;

      return user;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> removeCredential(String email) async {
    if (!isSupported) return;
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) return;
    await _storage.delete(key: _credentialKey(normalizedEmail));
  }

  Future<List<int>> _derivePasswordHash(String password, List<int> salt) async {
    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  String _credentialKey(String email) {
    final emailDigest = sha256.convert(utf8.encode(email)).bytes;
    return '$_keyPrefix${base64Url.encode(emailDigest).replaceAll('=', '')}';
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  bool _isEligibleRole(UserRole role) =>
      role == UserRole.admin || role == UserRole.cashier;

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}
