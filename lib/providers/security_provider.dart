import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/data/models/security_settings_model.dart';
import 'package:doctor_computer/data/models/biometric_credential_model.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/services/biometric_service.dart';

class SecurityProvider extends ChangeNotifier {
  SecuritySettingsModel _settings = SecuritySettingsModel.defaultSettings('');
  List<BiometricCredentialModel> _biometrics = [];
  bool _isLoading = false;

  SecuritySettingsModel get settings => _settings;
  List<BiometricCredentialModel> get biometrics => _biometrics;
  bool get isLoading => _isLoading;

  bool hasBiometricType(String type) =>
      _biometrics.any((b) => b.biometricType == type && b.isActive);

  bool get hasFingerprint => hasBiometricType('fingerprint');

  bool get requiresAuthForPayment =>
      (_settings.biometricForPayment && _settings.biometricEnabled) ||
      (_settings.pinForPayment && _settings.pinEnabled);

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  void reset() {
    _settings = SecuritySettingsModel.defaultSettings('');
    _biometrics = [];
    notifyListeners();
  }

  Future<void> loadSettings(String userId) async {
    if (userId.isEmpty) {
      reset();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // 1. Load settings & biometrics from local cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('security_settings_$userId');
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        _settings = SecuritySettingsModel.fromMap(decoded, fallbackUserId: userId);
      } else {
        _settings = SecuritySettingsModel.defaultSettings(userId);
      }

      final cachedBioJson = prefs.getString('biometrics_list_$userId');
      if (cachedBioJson != null) {
        final List list = jsonDecode(cachedBioJson);
        _biometrics = list.map((m) => BiometricCredentialModel.fromMap(m)).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[SecurityProvider] Error loading local cache: $e');
    }

    // 2. Fetch latest settings from Supabase
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('user_security_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _settings = SecuritySettingsModel.fromMap(response, fallbackUserId: userId);
        await _cacheSettingsLocally();
      } else {
        try {
          final newSettings = SecuritySettingsModel.defaultSettings(userId);
          await supabase.from('user_security_settings').upsert(newSettings.toMap(forDatabase: true));
          _settings = newSettings;
          await _cacheSettingsLocally();
        } catch (_) {}
      }

      // 3. Fetch latest biometric credentials from user_biometrics table
      await _fetchBiometricsFromSupabase(userId);
    } catch (e) {
      debugPrint('[SecurityProvider] Notice on Supabase sync: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchBiometricsFromSupabase(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final List res = await supabase
          .from('user_biometrics')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      if (res.isNotEmpty) {
        _biometrics = res.map((item) => BiometricCredentialModel.fromMap(item as Map<String, dynamic>)).toList();
        await _cacheBiometricsLocally();

        if (_biometrics.isNotEmpty && !_settings.biometricEnabled) {
          _settings = _settings.copyWith(biometricEnabled: true);
          await _cacheSettingsLocally();
        }
      }
    } catch (e) {
      debugPrint('[SecurityProvider] Notice loading user_biometrics table: $e');
    }
  }

  Future<void> _cacheSettingsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'security_settings_${_settings.userId}',
        jsonEncode(_settings.toMap()),
      );
    } catch (e) {
      debugPrint('[SecurityProvider] Error caching settings: $e');
    }
  }

  Future<void> _cacheBiometricsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'biometrics_list_${_settings.userId}',
        jsonEncode(_biometrics.map((b) => b.toMap()).toList()),
      );
    } catch (e) {
      debugPrint('[SecurityProvider] Error caching biometrics: $e');
    }
  }

  Future<bool> _persistSettings(SecuritySettingsModel newSettings) async {
    _settings = newSettings;
    notifyListeners();

    await _cacheSettingsLocally();

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('user_security_settings').upsert(_settings.toMap(forDatabase: true));
      return true;
    } catch (e) {
      debugPrint('[SecurityProvider] Error updating Supabase: $e');
      return true;
    }
  }

  /// Enroll real physical fingerprint hardware
  Future<bool> enrollFingerprintHardware({
    required UserModel user,
    required String credentialName,
  }) async {
    final authenticated = await BiometricService.authenticateWithFingerprint(
      localizedReason: 'Tempelkan sidik jari Anda pada sensor perangkat untuk mendaftar',
    );

    if (!authenticated) {
      return false;
    }

    final randomId = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final token = sha256.convert(utf8.encode('${user.id}_fingerprint_$randomId')).toString();

    final newCredential = BiometricCredentialModel(
      id: randomId,
      userId: user.id,
      biometricType: 'fingerprint',
      credentialName: credentialName.isNotEmpty ? credentialName : 'Sidik Jari ${biometrics.length + 1}',
      deviceModel: 'Sensor Sidik Jari Sistem',
      biometricToken: token,
      isActive: true,
      createdAt: DateTime.now(),
    );

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('user_biometrics').insert({
        'user_id': user.id,
        'biometric_type': 'fingerprint',
        'credential_name': newCredential.credentialName,
        'device_model': newCredential.deviceModel,
        'biometric_token': newCredential.biometricToken,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[SecurityProvider] Notice inserting to user_biometrics: $e');
    }

    _biometrics.insert(0, newCredential);
    await _cacheBiometricsLocally();

    await setBiometricEnabled(true, currentUser: user);
    return true;
  }

  /// Delete biometric credential
  Future<void> deleteBiometricCredential(String credentialTokenOrId) async {
    _biometrics.removeWhere((b) => b.id == credentialTokenOrId || b.biometricToken == credentialTokenOrId);
    await _cacheBiometricsLocally();

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('user_biometrics')
          .delete()
          .or('id.eq.$credentialTokenOrId,biometric_token.eq.$credentialTokenOrId');
    } catch (e) {
      debugPrint('[SecurityProvider] Notice deleting user_biometrics: $e');
    }

    if (_biometrics.isEmpty) {
      await setBiometricEnabled(false);
    } else {
      notifyListeners();
    }
  }

  Future<bool> setBiometricEnabled(bool value, {UserModel? currentUser}) async {
    final updated = _settings.copyWith(
      biometricEnabled: value,
      biometricForPayment: value ? _settings.biometricForPayment : false,
      updatedAt: DateTime.now(),
    );

    if (value && currentUser != null) {
      await saveBiometricUser(currentUser);
    }

    return _persistSettings(updated);
  }

  Future<void> saveBiometricUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_biometric_user', jsonEncode(user.toMap()));
    } catch (e) {
      debugPrint('[SecurityProvider] Error saving biometric user: $e');
    }
  }

  Future<bool> setBiometricForPayment(bool value) async {
    final updated = _settings.copyWith(
      biometricForPayment: value,
      updatedAt: DateTime.now(),
    );
    return _persistSettings(updated);
  }

  Future<bool> setPin(String newPin) async {
    if (newPin.length < 4 || newPin.length > 6) return false;
    final hash = _hashPin(newPin);
    final updated = _settings.copyWith(
      pinEnabled: true,
      pinHash: hash,
      updatedAt: DateTime.now(),
    );
    return _persistSettings(updated);
  }

  Future<bool> verifyPin(String inputPin) async {
    if (_settings.pinHash == null || !_settings.pinEnabled) return false;
    final hash = _hashPin(inputPin);
    return hash == _settings.pinHash;
  }

  Future<bool> removePin() async {
    final updated = _settings.copyWith(
      pinEnabled: false,
      pinHash: null,
      pinForPayment: false,
      updatedAt: DateTime.now(),
    );
    return _persistSettings(updated);
  }

  Future<bool> setPinForPayment(bool value) async {
    final updated = _settings.copyWith(
      pinForPayment: value,
      updatedAt: DateTime.now(),
    );
    return _persistSettings(updated);
  }

  Future<bool> setTwoFactorEnabled(bool value, {String? method}) async {
    final updated = _settings.copyWith(
      twoFactorEnabled: value,
      twoFactorMethod: method ?? _settings.twoFactorMethod,
      updatedAt: DateTime.now(),
    );
    return _persistSettings(updated);
  }

  Future<bool> setTwoFactorMethod(String method) async {
    final updated = _settings.copyWith(
      twoFactorMethod: method,
      updatedAt: DateTime.now(),
    );
    return _persistSettings(updated);
  }

  Future<bool> setAutoLockMinutes(int minutes) async {
    final updated = _settings.copyWith(
      autoLockMinutes: minutes,
      updatedAt: DateTime.now(),
    );
    return _persistSettings(updated);
  }

  Future<bool> setLoginNotification(bool value) async {
    final updated = _settings.copyWith(
      loginNotification: value,
      updatedAt: DateTime.now(),
    );
    return _persistSettings(updated);
  }
}
