import 'package:doctor_computer/core/constants/app_constants.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';

enum BuildServiceTier { standard, premium }

/// Represents a custom PC build matching the Supabase pc_builds table schema.
class PcBuildModel {
  final String? id;
  final String? userId;
  final Map<PcPartCategory, PcPartModel?> selectedParts;
  final BuildServiceTier serviceTier;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PcBuildModel({
    this.id,
    this.userId,
    required this.selectedParts,
    this.serviceTier = BuildServiceTier.standard,
    this.createdAt,
    this.updatedAt,
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

  Map<String, dynamic> toSupabaseMap(String activeUserId) {
    return {
      if (id != null) 'id': id,
      'user_id': activeUserId,
      'cpu_id': selectedParts[PcPartCategory.cpu]?.id,
      'gpu_id': selectedParts[PcPartCategory.gpu]?.id,
      'motherboard_id': selectedParts[PcPartCategory.motherboard]?.id,
      'ram_id': selectedParts[PcPartCategory.ram]?.id,
      'storage_id': selectedParts[PcPartCategory.storage]?.id,
      'psu_id': selectedParts[PcPartCategory.psu]?.id,
      'case_id': selectedParts[PcPartCategory.pcCase]?.id,
      'cooler_id': selectedParts[PcPartCategory.cooler]?.id,
      'service_tier': serviceTier.name,
      'total_parts_price': totalPartsPrice,
      'build_fee': buildFee,
      'grand_total': grandTotal,
      'is_complete': isComplete,
    };
  }

  factory PcBuildModel.fromSupabaseMap(
    Map<String, dynamic> map, {
    Map<String, PcPartModel>? partsLookup,
  }) {
    BuildServiceTier tier = BuildServiceTier.standard;
    if (map['service_tier']?.toString().toLowerCase() == 'premium') {
      tier = BuildServiceTier.premium;
    }

    PcPartModel? resolvePart(dynamic id) {
      if (id == null || partsLookup == null) return null;
      return partsLookup[id.toString()];
    }

    final parts = <PcPartCategory, PcPartModel?>{
      PcPartCategory.cpu: resolvePart(map['cpu_id']),
      PcPartCategory.gpu: resolvePart(map['gpu_id']),
      PcPartCategory.motherboard: resolvePart(map['motherboard_id']),
      PcPartCategory.ram: resolvePart(map['ram_id']),
      PcPartCategory.storage: resolvePart(map['storage_id']),
      PcPartCategory.psu: resolvePart(map['psu_id']),
      PcPartCategory.pcCase: resolvePart(map['case_id']),
      PcPartCategory.cooler: resolvePart(map['cooler_id']),
    };

    return PcBuildModel(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString(),
      selectedParts: parts,
      serviceTier: tier,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}
