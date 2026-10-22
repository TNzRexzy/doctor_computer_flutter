/// Represents a brand from the database.
class BrandModel {
  final String code;
  final String name;

  const BrandModel({
    required this.code,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
    };
  }

  factory BrandModel.fromMap(Map<String, dynamic> map) {
    return BrandModel(
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
    );
  }
}
