import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/data/models/pc_build_model.dart';
import 'package:doctor_computer/data/mock/mock_pc_parts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/core/constants/app_constants.dart';

class PcBuilderProvider extends ChangeNotifier {
  final Map<PcPartCategory, PcPartModel?> _selectedParts = {
    for (var category in PcPartCategory.values) category: null
  };
  BuildServiceTier _serviceTier = BuildServiceTier.standard;

  Map<PcPartCategory, PcPartModel?> get selectedParts => Map.unmodifiable(_selectedParts);
  BuildServiceTier get serviceTier => _serviceTier;

  List<PcPartModel> _allParts = [];
  bool _isLoading = false;

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
      if (cpu.compatibilityTags.contains('intel_lga1700') && mobo.compatibilityTags.contains('amd_am5')) {
        issues.add('CPU dan Motherboard tidak kompatibel (LGA 1700 vs AM5)');
      } else if (cpu.compatibilityTags.contains('amd_am5') && mobo.compatibilityTags.contains('intel_lga1700')) {
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

  List<PcPartModel> get allParts => _allParts.isNotEmpty ? _allParts : mockPcParts;
  bool get isLoading => _isLoading;

  List<PcPartModel> getPartsForCategory(PcPartCategory category) {
    final list = allParts.where((part) => part.category == category).toList();
    if (list.isEmpty) {
      return mockPcParts.where((part) => part.category == category).toList();
    }
    return list;
  }

  Future<void> reloadParts() async {
    await _loadParts();
  }

  Future<void> _loadParts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List res = await Supabase.instance.client
          .from('pc_parts')
          .select();

      if (res.isNotEmpty) {
        _allParts = res.map((p) => _mapPart(p)).toList();
        // Also combine with mock parts to ensure all categories have choices
        for (var mock in mockPcParts) {
          if (!_allParts.any((p) => p.name == mock.name)) {
            _allParts.add(mock);
          }
        }
      } else {
        _allParts = List.from(mockPcParts);
      }
    } catch (e) {
      debugPrint('Error loading pc parts from Supabase: $e');
      _allParts = List.from(mockPcParts);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  PcPartModel _mapPart(dynamic p) {
    final categoryStr = (p['category']?.toString() ?? '').toLowerCase();
    PcPartCategory category = PcPartCategory.cpu;

    if (categoryStr == 'cat-001' || categoryStr == 'cpu' || categoryStr.contains('processor')) {
      category = PcPartCategory.cpu;
    } else if (categoryStr == 'cat-002' || categoryStr == 'gpu' || categoryStr.contains('vga') || categoryStr.contains('graphics')) {
      category = PcPartCategory.gpu;
    } else if (categoryStr == 'cat-003' || categoryStr == 'motherboard' || categoryStr.contains('mobo')) {
      category = PcPartCategory.motherboard;
    } else if (categoryStr == 'cat-004' || categoryStr == 'ram' || categoryStr.contains('memory')) {
      category = PcPartCategory.ram;
    } else if (categoryStr == 'cat-005' || categoryStr == 'storage' || categoryStr.contains('ssd') || categoryStr.contains('hdd')) {
      category = PcPartCategory.storage;
    } else if (categoryStr == 'cat-006' || categoryStr == 'psu' || categoryStr.contains('power')) {
      category = PcPartCategory.psu;
    } else if (categoryStr == 'cat-007' || categoryStr == 'cooler' || categoryStr.contains('cooling')) {
      category = PcPartCategory.cooler;
    } else if (categoryStr == 'cat-008' || categoryStr == 'pc_case' || categoryStr == 'case' || categoryStr.contains('casing')) {
      category = PcPartCategory.pcCase;
    }

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

    return PcPartModel(
      id: p['id']?.toString() ?? '',
      name: p['name']?.toString() ?? '',
      category: category,
      brand: p['brand']?.toString() ?? 'Generic',
      price: (p['price'] as num?)?.toDouble() ?? 0.0,
      specs: specsMap,
      imageUrl: p['image_url']?.toString(),
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
