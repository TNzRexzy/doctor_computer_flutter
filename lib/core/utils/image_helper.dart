import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AppImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from Gallery or Camera and converts to a base64 Data URI string.
  /// If [maxWidth], [maxHeight], or [imageQuality] are provided, it compresses the image.
  static Future<String?> pickImageAsBase64({
    ImageSource source = ImageSource.gallery,
    double maxWidth = 800,
    double maxHeight = 800,
    int imageQuality = 80,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final extension = file.name.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      final base64String = base64Encode(bytes);
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Converts an image string (URL or data:image/...;base64,...) to an ImageProvider.
  static ImageProvider? getImageProvider(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    final s = source.trim();

    if (s.startsWith('data:image') && s.contains('base64,')) {
      try {
        final base64Part = s.split('base64,').last;
        final bytes = base64Decode(base64Part);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error decoding base64 image provider: $e');
        return null;
      }
    }

    if (s.startsWith('http://') || s.startsWith('https://')) {
      return NetworkImage(s);
    }

    if (s.startsWith('assets/')) {
      return AssetImage(s);
    }

    if (!kIsWeb && File(s).existsSync()) {
      return FileImage(File(s));
    }

    return NetworkImage(s);
  }
}
