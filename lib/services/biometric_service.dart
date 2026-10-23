import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the physical device has biometric hardware (Fingerprint / Face)
  static Future<bool> isBiometricHardwareAvailable() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } catch (e) {
      debugPrint('[BiometricService] Hardware check error: $e');
      return false;
    }
  }

  /// List available biometric types on device (e.g. fingerprint, face, iris)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[BiometricService] Error getting biometric types: $e');
      return [];
    }
  }

  /// Check if Fingerprint is supported/enrolled in phone system
  static Future<bool> hasFingerprintHardwareEnrolled() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.contains(BiometricType.fingerprint) || biometrics.contains(BiometricType.strong);
    } catch (e) {
      return false;
    }
  }

  /// Authenticate using actual physical device sensor (Fingerprint hardware prompt)
  static Future<bool> authenticateWithFingerprint({
    String localizedReason = 'Pindai sidik jari Anda pada sensor perangkat untuk verifikasi',
  }) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] PlatformException on fingerprint: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[BiometricService] Error authenticating fingerprint: $e');
      return false;
    }
  }


}
