import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/data/models/pc_build_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/core/constants/app_constants.dart';
import 'package:doctor_computer/core/constants/app_images.dart';

class PcBuilderProvider extends ChangeNotifier {
  final Map<PcPartCategory, PcPartModel?> _selectedParts = {
    for (var category in PcPartCategory.values) category: null,
  };
  BuildServiceTier _serviceTier = BuildServiceTier.standard;

  Map<PcPartCategory, PcPartModel?> get selectedParts =>
      Map.unmodifiable(_selectedParts);
  BuildServiceTier get serviceTier => _serviceTier;

  List<PcPartModel> _allParts = [];
  bool _isLoading = false;
  String? _errorMessage;

  double get totalPartsPrice {
    double total = 0;
    for (var part in _selectedParts.values) {
      if (part != null) {
        total += part.price;
      }
    }
    return total;
  }

  double get buildFee {
    return _serviceTier == BuildServiceTier.standard
        ? AppConstants.standardBuildFee
        : AppConstants.premiumBuildFee;
  }

  double get grandTotal => totalPartsPrice + buildFee;

  bool get isComplete {
    return _selectedParts.values.every((part) => part != null);
  }

  List<String> get compatibilityIssues {
    List<String> issues = [];
    final cpu = _selectedParts[PcPartCategory.cpu];
    final mobo = _selectedParts[PcPartCategory.motherboard];
    final ram = _selectedParts[PcPartCategory.ram];

    if (cpu != null && mobo != null) {
      if (cpu.compatibilityTags.contains('intel_lga1700') &&
          mobo.compatibilityTags.contains('amd_am5')) {
        issues.add('CPU dan Motherboard tidak kompatibel (LGA 1700 vs AM5)');
      } else if (cpu.compatibilityTags.contains('amd_am5') &&
          mobo.compatibilityTags.contains('intel_lga1700')) {
        issues.add('CPU dan Motherboard tidak kompatibel (AM5 vs LGA 1700)');
      }
    }

    if (ram != null && mobo != null) {
      bool ramIsDdr5 = ram.compatibilityTags.contains('ddr5');
      bool moboNeedsDdr5 = mobo.compatibilityTags.contains('ddr5');
      bool ramIsDdr4 = ram.compatibilityTags.contains('ddr4');
      bool moboNeedsDdr4 = mobo.compatibilityTags.contains('ddr4');

      if (ramIsDdr5 && moboNeedsDdr4 && !moboNeedsDdr5) {
        issues.add('Tipe RAM (DDR5) tidak sesuai dengan Motherboard (DDR4)');
      } else if (ramIsDdr4 && moboNeedsDdr5 && !moboNeedsDdr4) {
        issues.add('Tipe RAM (DDR4) tidak sesuai dengan Motherboard (DDR5)');
      }
    }

    return issues;
  }

  PcBuilderProvider() {
    _loadParts();
  }

  /// Semua komponen PC yang berasal dari tabel `pc_parts` di database.
  /// Tidak ada data mock / fallback: jika DB kosong atau gagal, list kosong.
  List<PcPartModel> get allParts => List.unmodifiable(_allParts);
  bool get isLoading => _isLoading;

  /// Pesan error jika pemuatan dari database gagal (null jika berhasil).
  String? get errorMessage => _errorMessage;

  List<PcPartModel> getPartsForCategory(PcPartCategory category) {
    return _allParts.where((part) => part.category == category).toList();
  }

  Future<void> reloadParts() async {
    await _loadParts();
  }

  Future<void> _loadParts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List res = await Supabase.instance.client.from('pc_parts').select();

      // Hanya komponen PC asli: baris dengan kategori di luar 8 slot
      // (mis. Laptop 'cat-010', Peripherals 'cat-009') dilewati.
      // Gambar part yang kosong di pc_parts dilengkapi dari tabel products
      // (produk dengan nama yang sama), karena foto diunggah saat input produk.
      final productsByName = await _loadProductsByName();
      _allParts = res
          .map((p) => _mapPart(p, productsByName))
          .whereType<PcPartModel>()
          .toList();
    } catch (e) {
      debugPrint('Error loading pc parts from Supabase: $e');
      _allParts = [];
      _errorMessage = 'Gagal memuat komponen dari database.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static String _normalizeName(String? name) =>
      (name ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Peta nama produk ternormalisasi ke ID dan foto produk di katalog.
  /// Gagal memuat tidak menghentikan pemuatan part (hasilnya kosong).
  Future<Map<String, Map<String, String>>> _loadProductsByName() async {
    final Map<String, Map<String, String>> result = {};
    try {
      final List rows = await Supabase.instance.client
          .from('products')
          .select('id, name, image_url');
      for (final row in rows) {
        final key = _normalizeName(row['name']?.toString());
        if (key.isEmpty || result.containsKey(key)) continue;
        final raw = row['image_url'];
        String? image;
        if (raw is List) {
          for (final item in raw) {
            final value = item?.toString().trim() ?? '';
            if (value.isNotEmpty) {
              image = value;
              break;
            }
          }
        } else if (raw is String) {
          image = raw.trim();
        }
        result[key] = {
          'id': row['id']?.toString() ?? '',
          'image_url': image ?? '',
        };
      }
    } catch (e) {
      debugPrint('Error loading product images for pc parts: $e');
    }
    return result;
  }

  PcPartModel? _mapPart(
    dynamic p, [
    Map<String, Map<String, String>> productsByName = const {},
  ]) {
    final categoryStr = (p['category']?.toString() ?? '').toLowerCase();
    PcPartCategory? category;

    if (categoryStr == 'cat-001' ||
        categoryStr == 'cpu' ||
        categoryStr.contains('processor')) {
      category = PcPartCategory.cpu;
    } else if (categoryStr == 'cat-002' ||
        categoryStr == 'gpu' ||
        categoryStr.contains('vga') ||
        categoryStr.contains('graphics')) {
      category = PcPartCategory.gpu;
    } else if (categoryStr == 'cat-003' ||
        categoryStr == 'motherboard' ||
        categoryStr.contains('mobo')) {
      category = PcPartCategory.motherboard;
    } else if (categoryStr == 'cat-004' ||
        categoryStr == 'ram' ||
        categoryStr.contains('memory')) {
      category = PcPartCategory.ram;
    } else if (categoryStr == 'cat-005' ||
        categoryStr == 'storage' ||
        categoryStr.contains('ssd') ||
        categoryStr.contains('hdd')) {
      category = PcPartCategory.storage;
    } else if (categoryStr == 'cat-006' ||
        categoryStr == 'psu' ||
        categoryStr.contains('power')) {
      category = PcPartCategory.psu;
    } else if (categoryStr == 'cat-007' ||
        categoryStr == 'cooler' ||
        categoryStr.contains('cooling')) {
      category = PcPartCategory.cooler;
    } else if (categoryStr == 'cat-008' ||
        categoryStr == 'pc_case' ||
        categoryStr == 'case' ||
        categoryStr.contains('casing')) {
      category = PcPartCategory.pcCase;
    }

    // Kategori tidak dikenali (bukan komponen rakitan) -> jangan ditampilkan.
    if (category == null) return null;

    final specsRaw = p['specs'];
    Map<String, String> specsMap = {};
    if (specsRaw is Map) {
      specsMap = specsRaw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    final rawTags = p['compatibility_tags'];
    List<String> tags = [];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    }

    // Gambar hanya dari kolom image_url di database (path bucket atau URL penuh).
    // Tidak ada tebak-tebakan gambar berdasarkan nama agar tidak salah gambar.
    final rawImage = p['image_url'];
    String? imageUrl;
    if (rawImage is List && rawImage.isNotEmpty) {
      imageUrl = rawImage.first?.toString();
    } else if (rawImage is String) {
      imageUrl = rawImage;
    }
    imageUrl = imageUrl?.trim();
    final matchedProduct =
        productsByName[_normalizeName(p['name']?.toString())];
    if (imageUrl == null || imageUrl.isEmpty) {
      imageUrl = matchedProduct?['image_url'];
    }
    imageUrl = (imageUrl == null || imageUrl.isEmpty)
        ? null
        : AppImages.getBucketUrl(imageUrl);

    return PcPartModel(
      id: p['id']?.toString() ?? '',
      name: p['name']?.toString() ?? '',
      category: category,
      brand: p['brand']?.toString() ?? 'Generic',
      price: (p['price'] as num?)?.toDouble() ?? 0.0,
      specs: specsMap,
      productId: p['product_id']?.toString().trim().isNotEmpty == true
          ? p['product_id'].toString().trim()
          : matchedProduct?['id'],
      imageUrl: imageUrl,
      compatibilityTags: tags,
    );
  }

  void selectPart(PcPartCategory category, PcPartModel part) {
    _selectedParts[category] = part;
    notifyListeners();
  }

  void removePart(PcPartCategory category) {
    _selectedParts[category] = null;
    notifyListeners();
  }

  void setServiceTier(BuildServiceTier tier) {
    _serviceTier = tier;
    notifyListeners();
  }

  void clearBuild() {
    for (var category in PcPartCategory.values) {
      _selectedParts[category] = null;
    }
    _serviceTier = BuildServiceTier.standard;
    notifyListeners();
  }
}
