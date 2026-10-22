/// Represents a product in the store.
class ProductModel {
  final String id;
  final String name;
  final String description;
  final String descriptionId;
  final double price;
  final double? originalPrice;
  final String categoryId;
  final String brand;
  final List<String> images;
  final Map<String, String> specs;
  final double rating;
  final int reviewCount;
  final int stock;
  final bool isNew;
  final bool isOnSale;
  final String? sku;
  final String? brandCode;
  final String? subtype;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.descriptionId,
    required this.price,
    this.originalPrice,
    required this.categoryId,
    required this.brand,
    required this.images,
    required this.specs,
    required this.rating,
    required this.reviewCount,
    required this.stock,
    required this.isNew,
    required this.isOnSale,
    this.sku,
    this.brandCode,
    this.subtype,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  double get discountPercentage =>
      hasDiscount ? ((originalPrice! - price) / originalPrice! * 100) : 0;

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    String? descriptionId,
    double? price,
    double? originalPrice,
    String? categoryId,
    String? brand,
    List<String>? images,
    Map<String, String>? specs,
    double? rating,
    int? reviewCount,
    int? stock,
    bool? isNew,
    bool? isOnSale,
    String? sku,
    String? brandCode,
    String? subtype,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      descriptionId: descriptionId ?? this.descriptionId,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      categoryId: categoryId ?? this.categoryId,
      brand: brand ?? this.brand,
      images: images ?? this.images,
      specs: specs ?? this.specs,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      stock: stock ?? this.stock,
      isNew: isNew ?? this.isNew,
      isOnSale: isOnSale ?? this.isOnSale,
      sku: sku ?? this.sku,
      brandCode: brandCode ?? this.brandCode,
      subtype: subtype ?? this.subtype,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'description_id': descriptionId,
      'price': price,
      'original_price': originalPrice,
      'category_id': categoryId,
      'brand': brand,
      'image_url': images,
      'specs': specs,
      'rating': rating,
      'review_count': reviewCount,
      'stock': stock,
      'is_new': isNew,
      'is_on_sale': isOnSale,
      if (sku != null) 'sku': sku,
      if (brandCode != null) 'brand_code': brandCode,
      if (subtype != null) 'subtype': subtype,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedImages = [];
    if (map['image_url'] is List) {
      parsedImages = (map['image_url'] as List).map((e) => e.toString()).toList();
    } else if (map['images'] is List) {
      parsedImages = (map['images'] as List).map((e) => e.toString()).toList();
    } else if (map['image_url'] is String && map['image_url'].toString().isNotEmpty) {
      parsedImages = [map['image_url'].toString()];
    }

    Map<String, String> parsedSpecs = {};
    if (map['specs'] is Map) {
      parsedSpecs = (map['specs'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    final price = (map['price'] as num?)?.toDouble() ?? 0.0;
    final origPrice = (map['original_price'] as num?)?.toDouble();

    return ProductModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      descriptionId: map['description_id']?.toString() ?? map['description']?.toString() ?? '',
      price: price,
      originalPrice: origPrice != null && origPrice > 0 ? origPrice : null,
      categoryId: map['category_id']?.toString() ?? '',
      brand: map['brand']?.toString() ?? 'Generic',
      images: parsedImages,
      specs: parsedSpecs,
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: (map['review_count'] as num?)?.toInt() ?? 10,
      stock: (map['stock'] as num?)?.toInt() ?? 10,
      isNew: map['is_new'] as bool? ?? false,
      isOnSale: map['is_on_sale'] as bool? ?? (origPrice != null && origPrice > price),
      sku: map['sku']?.toString(),
      brandCode: map['brand_code']?.toString(),
      subtype: map['subtype']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}
