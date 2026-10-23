class BiometricCredentialModel {
  final String id;
  final String userId;
  final String biometricType; // 'fingerprint'
  final String credentialName;
  final String? deviceModel;
  final String biometricToken;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  const BiometricCredentialModel({
    required this.id,
    required this.userId,
    required this.biometricType,
    required this.credentialName,
    this.deviceModel,
    required this.biometricToken,
    this.isActive = true,
    required this.createdAt,
    this.lastUsedAt,
  });

  factory BiometricCredentialModel.fromMap(Map<String, dynamic> map) {
    return BiometricCredentialModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      biometricType: map['biometric_type']?.toString() ?? 'fingerprint',
      credentialName: map['credential_name']?.toString() ?? 'Sidik Jari',
      deviceModel: map['device_model']?.toString(),
      biometricToken: map['biometric_token']?.toString() ?? '',
      isActive: map['is_active'] != false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastUsedAt: map['last_used_at'] != null
          ? DateTime.tryParse(map['last_used_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'biometric_type': biometricType,
      'credential_name': credentialName,
      'device_model': deviceModel,
      'biometric_token': biometricToken,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'last_used_at': lastUsedAt?.toIso8601String(),
    };
  }
}
