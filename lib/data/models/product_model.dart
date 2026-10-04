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
  });

  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  double get discountPercentage => hasDiscount ? ((originalPrice! - price) / originalPrice! * 100) : 0;
}
