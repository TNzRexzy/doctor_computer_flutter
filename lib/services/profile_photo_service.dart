import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Foto yang sudah dipilih dan divalidasi, siap diunggah.
class PickedProfilePhoto {
  final Uint8List bytes;
  final String extension;
  final String contentType;

  const PickedProfilePhoto({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });
}

/// Foto profil (semua role: client, cashier, admin). File JPG/PNG/GIF dipilih
/// dari perangkat lalu diunggah ke bucket `profile-photos` di folder milik
/// user (`<user_id>/<timestamp>.<ext>`).
class ProfilePhotoService {
  ProfilePhotoService._();

  static const String bucketName = 'profile-photos';
  static const int maxBytes = 5 * 1024 * 1024;

  static final ImagePicker _picker = ImagePicker();

  /// Membuka galeri/file chooser. Mengembalikan `null` jika dibatalkan.
  /// Melempar [FormatException] dengan pesan yang aman ditampilkan.
  /// Tidak memakai `imageQuality` agar GIF tidak dikompres/kehilangan animasi.
  static Future<PickedProfilePhoto?> pick() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;

    final size = await file.length();
    if (size <= 0 || size > maxBytes) {
      throw FormatException(
        'Ukuran foto maksimal ${maxBytes ~/ (1024 * 1024)} MB.',
      );
    }

    final bytes = await file.readAsBytes();
    final type = _detectType(bytes);
    if (type == null) {
      throw const FormatException(
        'Format tidak didukung. Gunakan file JPG, PNG, atau GIF.',
      );
    }
    return PickedProfilePhoto(
      bytes: bytes,
      extension: type.$1,
      contentType: type.$2,
    );
  }

  /// Mengunggah [photo] dan mengembalikan URL publiknya.
  static Future<String> upload(PickedProfilePhoto photo, String userId) async {
    final path =
        '$userId/${DateTime.now().microsecondsSinceEpoch}.${photo.extension}';
    final storage = Supabase.instance.client.storage.from(bucketName);
    await storage.uploadBinary(
      path,
      photo.bytes,
      fileOptions: FileOptions(contentType: photo.contentType, upsert: false),
    );
    return storage.getPublicUrl(path);
  }

  /// Menghapus foto lama dari storage (best-effort). Hanya file di bucket
  /// ini yang dihapus; URL luar (mis. foto lama berbasis URL) diabaikan.
  static Future<void> deleteByUrl(String? url) async {
    if (url == null || url.isEmpty) return;
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
      debugPrint('[ProfilePhoto] delete failed: $e');
    }
  }

  /// Mendeteksi jenis gambar dari isi file (bukan dari nama file).
  static (String, String)? _detectType(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) {
      return ('jpg', 'image/jpeg');
    }
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4e &&
        b[3] == 0x47 &&
        b[4] == 0x0d &&
        b[5] == 0x0a &&
        b[6] == 0x1a &&
        b[7] == 0x0a) {
      return ('png', 'image/png');
    }
    if (b.length >= 6) {
      final head = String.fromCharCodes(b.sublist(0, 6));
      if (head == 'GIF87a' || head == 'GIF89a') return ('gif', 'image/gif');
    }
    return null;
  }
}
