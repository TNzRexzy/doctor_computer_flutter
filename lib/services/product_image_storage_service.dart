import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:doctor_computer/core/constants/app_images.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductImageStorageService {
  ProductImageStorageService._();

  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  static const Map<String, String> _allowedTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static Future<String> uploadProductImage(XFile file, String productId) async {
    final extension = file.name.split('.').last.toLowerCase();
    final contentType = _allowedTypes[extension];
    if (contentType == null) {
      throw const FormatException('Pilih gambar JPG, JPEG, PNG, atau WEBP.');
    }

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxFileSizeBytes) {
      throw const FormatException('Ukuran gambar harus kurang dari 10 MB.');
    }
    if (!_matchesImageType(bytes, contentType)) {
      throw const FormatException(
        'Isi file tidak sesuai dengan format gambar yang dipilih.',
      );
    }

    final path =
        'product-images/$productId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final storage = Supabase.instance.client.storage.from(AppImages.bucketName);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );
    return storage.getPublicUrl(path);
  }

  static bool _matchesImageType(Uint8List bytes, String contentType) {
    switch (contentType) {
      case 'image/jpeg':
        return bytes.length >= 3 &&
            bytes[0] == 0xff &&
            bytes[1] == 0xd8 &&
            bytes[2] == 0xff;
      case 'image/png':
        return bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4e &&
            bytes[3] == 0x47 &&
            bytes[4] == 0x0d &&
            bytes[5] == 0x0a &&
            bytes[6] == 0x1a &&
            bytes[7] == 0x0a;
      case 'image/webp':
        return bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      default:
        return false;
    }
  }

  static Future<void> deleteProductImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;

    final uri = Uri.tryParse(imageUrl);
    if (uri == null) return;
    final marker = '/storage/v1/object/public/${AppImages.bucketName}/';
    final markerIndex = uri.path.indexOf(marker);
    final s3Marker = '/storage/v1/s3/${AppImages.bucketName}/';
    final s3MarkerIndex = uri.path.indexOf(s3Marker);
    final markerStart = markerIndex >= 0
        ? markerIndex + marker.length
        : (s3MarkerIndex >= 0 ? s3MarkerIndex + s3Marker.length : -1);
    if (markerStart < 0) return;

    final objectPath = Uri.decodeComponent(uri.path.substring(markerStart));
    if (objectPath.startsWith('product-images/')) {
      await Supabase.instance.client.storage.from(AppImages.bucketName).remove([
        objectPath,
      ]);
    }
  }
}
