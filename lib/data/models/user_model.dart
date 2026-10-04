enum MembershipTier { bronze, silver, gold, platinum }

/// Represents a user in the application.
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String address;
  final String city;
  final MembershipTier membershipTier;
  final int points;
  final DateTime joinDate;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.address,
    required this.city,
    required this.membershipTier,
    required this.points,
    required this.joinDate,
  });

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? address,
    String? city,
    MembershipTier? membershipTier,
    int? points,
    DateTime? joinDate,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      address: address ?? this.address,
      city: city ?? this.city,
      membershipTier: membershipTier ?? this.membershipTier,
      points: points ?? this.points,
      joinDate: joinDate ?? this.joinDate,
    );
  }

  factory UserModel.guest() {
    return UserModel(
      id: 'guest',
      fullName: 'Guest User',
      email: '',
      phone: '',
      address: '',
      city: '',
      membershipTier: MembershipTier.bronze,
      points: 0,
      joinDate: DateTime.now(),
    );
  }
}
