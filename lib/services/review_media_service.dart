import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Foto & video ulasan produk. File diunggah ke bucket `review-media` di
/// folder milik user (`<user_id>/images|videos/...`).
class ReviewMediaService {
  ReviewMediaService._();

  static const String bucketName = 'review-media';
  static const int maxImages = 5;
  static const int maxVideos = 1;
  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxVideoBytes = 50 * 1024 * 1024;
  static const Duration maxVideoDuration = Duration(seconds: 60);

  static const Map<String, String> _imageTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const Map<String, String> _videoTypes = {
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
  };

  static final ImagePicker _picker = ImagePicker();

  /// `true` jika [url] menunjuk ke file video.
  static bool isVideoUrl(String url) {
    final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    return _videoTypes.containsKey(path.substring(dot + 1));
  }

  static bool isVideoFile(XFile file) => _videoTypes.containsKey(_extension(file));

  static String _extension(XFile file) {
    final name = file.name.isNotEmpty ? file.name : file.path;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  // ============================================================
  // MEMILIH FILE
  // ============================================================

  /// Memilih foto dari galeri sebanyak-banyaknya [remaining].
  static Future<List<XFile>> pickImages(int remaining) async {
    if (remaining <= 0) return const [];
    if (remaining == 1) {
      final single = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      return single == null ? const [] : [single];
    }
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      limit: remaining,
    );
    return picked.take(remaining).toList();
  }

  static Future<XFile?> pickVideo() {
    return _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: maxVideoDuration,
    );
  }

  // ============================================================
  // UPLOAD
  // ============================================================

  /// Memvalidasi lalu mengunggah [file]; mengembalikan URL publiknya.
  /// Melempar [FormatException] dengan pesan yang aman ditampilkan.
  static Future<String> upload(XFile file, String userId) async {
    final extension = _extension(file);
    final isVideo = _videoTypes.containsKey(extension);
    final contentType = isVideo ? _videoTypes[extension] : _imageTypes[extension];
    if (contentType == null) {
      throw const FormatException(
        'Format tidak didukung. Gunakan foto JPG/PNG/WEBP atau video MP4/MOV/WEBM.',
      );
    }

    final size = await file.length();
    final limit = isVideo ? maxVideoBytes : maxImageBytes;
    if (size <= 0 || size > limit) {
      throw FormatException(
        isVideo
            ? 'Ukuran video maksimal ${maxVideoBytes ~/ (1024 * 1024)} MB.'
            : 'Ukuran foto maksimal ${maxImageBytes ~/ (1024 * 1024)} MB.',
      );
    }

    final Uint8List bytes = await file.readAsBytes();
    if (!isVideo && !_matchesImageType(bytes, contentType)) {
      throw const FormatException(
        'Isi file tidak sesuai dengan format foto yang dipilih.',
      );
    }

    final folder = isVideo ? 'videos' : 'images';
    final path =
        '$userId/$folder/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final storage = Supabase.instance.client.storage.from(bucketName);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );
    return storage.getPublicUrl(path);
  }

  /// Menghapus file ulasan dari storage (best-effort, error diabaikan).
  static Future<void> deleteByUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      final marker = '/storage/v1/object/public/$bucketName/';
      final index = uri.path.indexOf(marker);
      if (index < 0) return;
      final objectPath = Uri.decodeComponent(
        uri.path.substring(index + marker.length),
      );
      await Supabase.instance.client.storage.from(bucketName).remove([
        objectPath,
      ]);
    } catch (e) {
      debugPrint('[ReviewMedia] delete failed: $e');
    }
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
}
