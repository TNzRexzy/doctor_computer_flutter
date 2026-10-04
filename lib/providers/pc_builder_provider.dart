import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/data/models/pc_build_model.dart';
import 'package:doctor_computer/data/mock/mock_pc_parts.dart';
import 'package:doctor_computer/core/constants/app_constants.dart';

class PcBuilderProvider extends ChangeNotifier {
  final Map<PcPartCategory, PcPartModel?> _selectedParts = {
    for (var category in PcPartCategory.values) category: null
  };
  BuildServiceTier _serviceTier = BuildServiceTier.standard;

  Map<PcPartCategory, PcPartModel?> get selectedParts => Map.unmodifiable(_selectedParts);
  BuildServiceTier get serviceTier => _serviceTier;

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
        issues.add('CPU dan Motherboard tidak kompatibel');
      } else if (cpu.compatibilityTags.contains('amd_am5') && mobo.compatibilityTags.contains('intel_lga1700')) {
        issues.add('CPU dan Motherboard tidak kompatibel');
      }
    }

    if (ram != null && mobo != null) {
      bool ramIsDdr5 = ram.compatibilityTags.contains('ddr5');
      bool moboNeedsDdr5 = mobo.compatibilityTags.contains('ddr5');
      if (ramIsDdr5 != moboNeedsDdr5) {
        issues.add('Tipe RAM tidak sesuai dengan Motherboard');
      }
    }

    return issues;
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

  List<PcPartModel> getPartsForCategory(PcPartCategory category) {
    return mockPcParts.where((part) => part.category == category).toList();
  }
}
