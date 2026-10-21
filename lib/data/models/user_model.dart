enum MembershipTier { bronze, silver, gold, platinum }

enum UserRole { user, cashier, admin }

/// Represents a user in the application.
class UserModel {
  /// Owner accounts of this installation. They can never be demoted back to
  /// `UserRole.user` by a stale profile row or a cached session, because the
  /// store owner must always be able to reach the admin dashboard.
  static const Set<String> ownerEmails = {
    'nopal48@gmail.com',
    'admin@doctorcomputer.id',
  };

  static const Set<String> cashierEmails = {
    'cashier@doctorcomputer.id',
  };

  /// Lowercases and trims an email, and expands the legacy `admin` / `cashier`
  /// username aliases used by the login form.
  static String normalizeEmail(String email) {
    final value = email.trim().toLowerCase();
    if (value == 'admin') return 'admin@doctorcomputer.id';
    if (value == 'cashier') return 'cashier@doctorcomputer.id';
    return value;
  }

  static bool isOwnerAccount(String email) =>
      ownerEmails.contains(normalizeEmail(email));

  static bool isCashierAccount(String email) =>
      cashierEmails.contains(normalizeEmail(email));

  /// Resolves the application role.
  ///
  /// `public.users.role` is the source of truth, so an explicit `admin` or
  /// `cashier` value always wins. Owner/cashier accounts fall back to their
  /// built-in role instead of `user`, which is what previously reset
  /// nopal48@gmail.com to a regular customer after `restoreSession()`.
  static UserRole resolveRole(dynamic rawRole, {String? email}) {
    final value = rawRole?.toString().trim().toLowerCase();
    if (value == 'admin') return UserRole.admin;
    if (value == 'cashier') return UserRole.cashier;

    if (email != null && email.isNotEmpty) {
      if (isOwnerAccount(email)) return UserRole.admin;
      if (isCashierAccount(email)) return UserRole.cashier;
    }

    return UserRole.user;
  }

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'address': address,
      'city': city,
      'membership_tier': membershipTier.name,
      'points': points,
      'join_date': joinDate.toIso8601String(),
      'role': role.name,
      'latitude': latitude,
      'longitude': longitude,
      'profile_image_url': profileImageUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    MembershipTier parseTier(dynamic t) {
      if (t == null) return MembershipTier.bronze;
      if (t is String) {
        switch (t.toLowerCase()) {
          case 'silver': return MembershipTier.silver;
          case 'gold': return MembershipTier.gold;
          case 'platinum': return MembershipTier.platinum;
          default: return MembershipTier.bronze;
        }
      }
      return MembershipTier.bronze;
    }

    final emailStr = map['email']?.toString() ?? '';
    return UserModel(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      email: emailStr,
      phone: map['phone']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString(),
      address: map['address']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      membershipTier: parseTier(map['membership_tier']),
      points: (map['points'] as num? ?? 0).toInt(),
      joinDate: map['join_date'] != null
          ? (DateTime.tryParse(map['join_date'].toString()) ?? DateTime.now())
          : DateTime.now(),
      role: resolveRole(map['role'], email: emailStr),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      profileImageUrl: map['profile_image_url']?.toString(),
    );
  }
}
