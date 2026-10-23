class SecuritySettingsModel {
  final String userId;
  final bool biometricEnabled;
  final bool biometricForPayment;
  final bool pinEnabled;
  final String? pinHash;
  final bool pinForPayment;
  final bool twoFactorEnabled;
  final String? twoFactorMethod;
  final int autoLockMinutes;
  final bool loginNotification;
  final List<String> enrolledBiometrics;
  final DateTime? updatedAt;

  const SecuritySettingsModel({
    required this.userId,
    this.biometricEnabled = false,
    this.biometricForPayment = false,
    this.pinEnabled = false,
    this.pinHash,
    this.pinForPayment = false,
    this.twoFactorEnabled = false,
    this.twoFactorMethod = 'email',
    this.autoLockMinutes = 0,
    this.loginNotification = true,
    this.enrolledBiometrics = const [],
    this.updatedAt,
  });

  factory SecuritySettingsModel.defaultSettings(String userId) {
    return SecuritySettingsModel(
      userId: userId,
      biometricEnabled: false,
      biometricForPayment: false,
      pinEnabled: false,
      pinHash: null,
      pinForPayment: false,
      twoFactorEnabled: false,
      twoFactorMethod: 'email',
      autoLockMinutes: 0,
      loginNotification: true,
      enrolledBiometrics: const [],
      updatedAt: DateTime.now(),
    );
  }

  factory SecuritySettingsModel.fromMap(Map<String, dynamic> map, {String? fallbackUserId}) {
    List<String> parsedBiometrics = [];
    if (map['enrolled_biometrics'] is List) {
      parsedBiometrics = (map['enrolled_biometrics'] as List).map((e) => e.toString()).toList();
    } else if (map['biometric_enabled'] == true) {
      parsedBiometrics = ['Sidik Jari Perangkat (Default)'];
    }

    return SecuritySettingsModel(
      userId: map['user_id']?.toString() ?? fallbackUserId ?? '',
      biometricEnabled: map['biometric_enabled'] == true,
      biometricForPayment: map['biometric_for_payment'] == true,
      pinEnabled: map['pin_enabled'] == true,
      pinHash: map['pin_hash']?.toString(),
      pinForPayment: map['pin_for_payment'] == true,
      twoFactorEnabled: map['two_factor_enabled'] == true,
      twoFactorMethod: map['two_factor_method']?.toString() ?? 'email',
      autoLockMinutes: map['auto_lock_minutes'] is int
          ? map['auto_lock_minutes'] as int
          : int.tryParse(map['auto_lock_minutes']?.toString() ?? '0') ?? 0,
      loginNotification: map['login_notification'] != false,
      enrolledBiometrics: parsedBiometrics,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap({bool forDatabase = false}) {
    final map = <String, dynamic>{
      'user_id': userId,
      'biometric_enabled': biometricEnabled,
      'biometric_for_payment': biometricForPayment,
      'pin_enabled': pinEnabled,
      'pin_hash': pinHash,
      'pin_for_payment': pinForPayment,
      'two_factor_enabled': twoFactorEnabled,
      'two_factor_method': twoFactorMethod,
      'auto_lock_minutes': autoLockMinutes,
      'login_notification': loginNotification,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
    if (!forDatabase) {
      map['enrolled_biometrics'] = enrolledBiometrics;
    }
    return map;
  }

  SecuritySettingsModel copyWith({
    String? userId,
    bool? biometricEnabled,
    bool? biometricForPayment,
    bool? pinEnabled,
    String? pinHash,
    bool? pinForPayment,
    bool? twoFactorEnabled,
    String? twoFactorMethod,
    int? autoLockMinutes,
    bool? loginNotification,
    List<String>? enrolledBiometrics,
    DateTime? updatedAt,
  }) {
    return SecuritySettingsModel(
      userId: userId ?? this.userId,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricForPayment: biometricForPayment ?? this.biometricForPayment,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pinHash: pinHash ?? this.pinHash,
      pinForPayment: pinForPayment ?? this.pinForPayment,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      twoFactorMethod: twoFactorMethod ?? this.twoFactorMethod,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      loginNotification: loginNotification ?? this.loginNotification,
      enrolledBiometrics: enrolledBiometrics ?? this.enrolledBiometrics,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
