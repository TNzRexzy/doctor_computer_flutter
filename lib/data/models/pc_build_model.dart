import 'package:doctor_computer/core/constants/app_constants.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';

enum BuildServiceTier { standard, premium }

/// Represents a custom PC build.
class PcBuildModel {
  final Map<PcPartCategory, PcPartModel?> selectedParts;
  final BuildServiceTier serviceTier;

  PcBuildModel({
    required this.selectedParts,
    this.serviceTier = BuildServiceTier.standard,
  });

  double get totalPartsPrice {
    double total = 0;
    for (var part in selectedParts.values) {
      if (part != null) {
        total += part.price;
      }
    }
    return total;
  }

  double get buildFee {
    return serviceTier == BuildServiceTier.standard
        ? AppConstants.standardBuildFee
        : AppConstants.premiumBuildFee;
  }

  double get grandTotal => totalPartsPrice + buildFee;

  bool get isComplete {
    return selectedParts.values.every((part) => part != null);
  }

  List<PcPartModel> get selectedPartsList {
    return selectedParts.values.whereType<PcPartModel>().toList();
  }

  List<String> get compatibilityIssues {
    List<String> issues = [];
    final cpu = selectedParts[PcPartCategory.cpu];
    final mobo = selectedParts[PcPartCategory.motherboard];
    final ram = selectedParts[PcPartCategory.ram];

    if (cpu != null && mobo != null) {
      if (cpu.compatibilityTags.contains('intel_lga1700') && mobo.compatibilityTags.contains('amd_am5')) {
        issues.add('CPU (Intel) dan Motherboard (AMD) tidak kompatibel');
      } else if (cpu.compatibilityTags.contains('amd_am5') && mobo.compatibilityTags.contains('intel_lga1700')) {
        issues.add('CPU (AMD) dan Motherboard (Intel) tidak kompatibel');
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
}
