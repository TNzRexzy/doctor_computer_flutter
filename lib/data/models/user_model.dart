enum MembershipTier { bronze, silver, gold, platinum }

enum UserRole { user, cashier, admin }

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
  final UserRole role;
  final double? latitude;
  final double? longitude;
  final String? profileImageUrl;

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
    this.role = UserRole.user,
    this.latitude,
    this.longitude,
    this.profileImageUrl,
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
    UserRole? role,
    double? latitude,
    double? longitude,
    String? profileImageUrl,
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
      role: role ?? this.role,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
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
      role: UserRole.user,
    );
  }
}
