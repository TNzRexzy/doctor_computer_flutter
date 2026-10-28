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
    return PcPartCompatibility.issues(
      cpu: selectedParts[PcPartCategory.cpu],
      motherboard: selectedParts[PcPartCategory.motherboard],
      ram: selectedParts[PcPartCategory.ram],
    );
  }
}
