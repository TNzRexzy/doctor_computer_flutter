import 'package:doctor_computer/core/config/env_config.dart';

/// Centralized image provider for Doctor Computer.
/// Resolves images from the Supabase Storage Bucket ('assets').
class AppImages {
  AppImages._();

  static const String appLogo = 'assets/images/logo.png';
  static const String bucketName = 'assets';

  // --- Exact files uploaded to Supabase Storage Bucket ('assets') ---
  // Gambar awal
  static const String fileCorsairVengeance = 'corsair vengeance.webp';
  static const String fileIntelI7 = 'intel I7.webp';
  static const String fileLogitechG502 = 'logitech G502 Hero.webp';
  static const String fileNoctuaNhD15 = 'noctua NH-D15.webp';
  static const String fileSamsung980 = 'samsung 980.webp';

  // Gambar tambahan (sesuai upload terbaru di bucket)
  static const String fileCorsairRm850x = 'corsair rm850x.webp';
  static const String fileAsusVivobook = 'asus vivobook 15 oled.webp';
  static const String fileFractalDesign = 'fractal design.webp';
  static const String fileMsiMag8660 = 'msi mag 8660.webp';
  static const String fileRtx4080 = 'rtx 4080.webp';
  static const String fileRtx4090 = 'rtx 4090.webp';

  /// Resolves any relative path to the Supabase storage S3 bucket URL.
  /// Handles URL encoding for spaces and special characters.
  static String getBucketUrl(String path) {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty) return '';
    
    // Jika sudah berupa URL lengkap
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return cleanPath;
    }
    
    // Jika menggunakan asset lokal
    if (cleanPath.startsWith('assets/images/')) {
      return cleanPath;
    }

    final storageUrl = EnvConfig.storageUrl;
    final bucket = EnvConfig.storageBucket;
    final normalizedPath = cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;
    final encodedPath = Uri.encodeComponent(normalizedPath).replaceAll('%2F', '/');

    if (storageUrl.endsWith('/s3') || storageUrl.contains('/s3/')) {
      return '$storageUrl/$bucket/$encodedPath';
    }
    return '$storageUrl/object/public/$bucket/$encodedPath';
  }

  /// Direct public object URL fallback if S3 gateway requires signature
  static String getPublicFallbackUrl(String path) {
    final cleanPath = path.trim();
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      if (cleanPath.contains('/storage/v1/s3/')) {
        return cleanPath.replaceAll('/storage/v1/s3/', '/storage/v1/object/public/');
      }
      return cleanPath;
    }
    final normalizedPath = cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;
    final encodedPath = Uri.encodeComponent(normalizedPath).replaceAll('%2F', '/');
    return '${EnvConfig.supabaseUrl}/storage/v1/object/public/${EnvConfig.storageBucket}/$encodedPath';
  }

  // --- Promo Banners (Sourced from Supabase Storage Bucket) ---
  static String get promoFlashSale => getBucketUrl(fileSamsung980);
  static String get promoPcBuilder => getBucketUrl(fileIntelI7);
  static String get promoMember => getBucketUrl(fileNoctuaNhD15);
  static String get promoShipping => getBucketUrl(fileLogitechG502);

  // --- Default Product Images from Supabase Storage ---
  static String getProductImageUrl(String productId) {
    return getBucketUrl('products/$productId.jpg');
  }

  /// Intelligent matcher for uploaded Supabase assets based on hardware names.
  /// Diurutkan dari spesifik ke umum untuk menghindari bentrok (misal: 'RTX 4090' vs 'NVIDIA').
  static String? matchUploadedImage(String name, [String? brand]) {
    final lower = '${name.toLowerCase()} ${(brand ?? '').toLowerCase()}';

    // --- 1. Spesifik GPU (RTX Series) ---
    if (lower.contains('rtx 4090') || lower.contains('4090')) {
      return fileRtx4090;
    }
    if (lower.contains('rtx 4080') || lower.contains('4080')) {
      return fileRtx4080;
    }

    // --- 2. Monitor MSI / Motherboard ---
    if (lower.contains('msi') || lower.contains('mag 8660') || lower.contains('monitor')) {
      return fileMsiMag8660;
    }

    // --- 3. Laptop ASUS ---
    if (lower.contains('asus') || lower.contains('vivobook') || lower.contains('oled')) {
      return fileAsusVivobook;
    }

    // --- 4. Casing Fractal ---
    if (lower.contains('fractal') || lower.contains('casing')) {
      return fileFractalDesign;
    }

    // --- 5. PSU Corsair RM850x ---
    if (lower.contains('rm850x') || lower.contains('psu') || lower.contains('850w')) {
      return fileCorsairRm850x;
    }

    // --- 6. RAM Corsair Vengeance ---
    if (lower.contains('corsair') && lower.contains('vengeance') || lower.contains('ddr5') || lower.contains('ram')) {
      return fileCorsairVengeance;
    }

    // --- 7. CPU Intel ---
    if (lower.contains('intel') || lower.contains('12700') || lower.contains('i7') || lower.contains('core i')) {
      return fileIntelI7;
    }

    // --- 8. Mouse Logitech ---
    if (lower.contains('logitech') || lower.contains('g502') || lower.contains('mouse') || lower.contains('hero')) {
      return fileLogitechG502;
    }

    // --- 9. Cooler Noctua ---
    if (lower.contains('noctua') || lower.contains('nh-d15') || lower.contains('d15') || lower.contains('cooler')) {
      return fileNoctuaNhD15;
    }

    // --- 10. SSD Samsung ---
    if (lower.contains('samsung') || lower.contains('980') || lower.contains('990') || lower.contains('ssd') || lower.contains('nvme')) {
      return fileSamsung980;
    }

    return null;
  }

  /// Resolve product images list from database value, uploaded Supabase assets, or bucket convention
  static List<String> resolveProductImages(
    dynamic rawImages,
    String productId, {
    String productName = '',
    String? categoryId,
    String? brand,
  }) {
    List<String> result = [];

    // 1. If database has explicit image_url
    if (rawImages is List) {
      for (final item in rawImages) {
        final str = item?.toString().trim();
        if (str != null && str.isNotEmpty) {
          result.add(getBucketUrl(str));
        }
      }
    } else if (rawImages is String && rawImages.trim().isNotEmpty) {
      result.add(getBucketUrl(rawImages.trim()));
    }

    // 2. If database image_url is empty, match with uploaded Supabase assets
    if (result.isEmpty) {
      final matchedUploaded = matchUploadedImage(productName, brand);
      if (matchedUploaded != null) {
        result.add(getBucketUrl(matchedUploaded));
      }
    }

    // 3. Fallback to product ID & category in the bucket
    if (result.isEmpty) {
      result.add(getProductImageUrl(productId));
      if (categoryId != null && categoryId.isNotEmpty) {
        result.add(getBucketUrl('categories/$categoryId.jpg'));
      }
    }

    return result;
  }
}