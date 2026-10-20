import 'package:doctor_computer/data/models/user_model.dart';

/// Represents a membership tier configuration.
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
    required this.benefitsId,
  });
}
