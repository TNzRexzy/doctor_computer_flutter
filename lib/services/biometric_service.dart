import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static final ImagePicker _imagePicker = ImagePicker();

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

  /// Authenticate using actual physical device sensor (Fingerprint hardware prompt)
  static Future<bool> authenticateWithHardware({
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
      debugPrint('[BiometricService] PlatformException on authenticate: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[BiometricService] Error authenticating: $e');
      return false;
    }
  }

  /// Capture face verification by opening the actual front camera
  static Future<XFile?> captureFaceFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
        maxWidth: 600,
      );
      return photo;
    } catch (e) {
      debugPrint('[BiometricService] Camera capture error: $e');
      return null;
    }
  }
}
