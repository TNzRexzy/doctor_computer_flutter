import 'package:doctor_computer/data/models/user_model.dart';

/// Represents a membership tier configuration matching the Supabase membership_tiers table.
class MembershipModel {
  final MembershipTier tier;
  final String name;
  final int requiredPoints;
  final double discountPercent;
  final List<String> benefits;
  final List<String> benefitsId;

  const MembershipModel({
    required this.tier,
    required this.name,
    required this.requiredPoints,
    required this.discountPercent,
    required this.benefits,
    this.benefitsId = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'tier': tier.name,
      'name': name,
      'required_points': requiredPoints,
      'discount_percent': discountPercent,
      'benefits': benefits,
    };
  }

  factory MembershipModel.fromMap(Map<String, dynamic> map) {
    final tierStr = (map['tier']?.toString() ?? 'bronze').toLowerCase();
    MembershipTier tier = MembershipTier.bronze;
    switch (tierStr) {
      case 'silver':
        tier = MembershipTier.silver;
        break;
      case 'gold':
        tier = MembershipTier.gold;
        break;
      case 'platinum':
        tier = MembershipTier.platinum;
        break;
      default:
        tier = MembershipTier.bronze;
    }

    List<String> benefitsList = [];
    if (map['benefits'] is List) {
      benefitsList = (map['benefits'] as List).map((e) => e.toString()).toList();
    }

    return MembershipModel(
      tier: tier,
      name: map['name']?.toString() ?? tier.name.toUpperCase(),
      requiredPoints: (map['required_points'] as num? ?? 0).toInt(),
      discountPercent: (map['discount_percent'] as num? ?? 0.0).toDouble(),
      benefits: benefitsList,
      benefitsId: benefitsList,
    );
  }
}
