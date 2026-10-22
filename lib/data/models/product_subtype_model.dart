/// Represents a product subtype from the database.
class ProductSubtypeModel {
  final String code;
  final String name;

  const ProductSubtypeModel({
    required this.code,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
    };
  }

  factory ProductSubtypeModel.fromMap(Map<String, dynamic> map) {
    return ProductSubtypeModel(
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
    );
  }
}
