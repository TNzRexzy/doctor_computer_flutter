import 'package:doctor_computer/data/models/product_model.dart';

/// Represents an item in the shopping cart.
class CartItemModel {
  final ProductModel product;
  int quantity;

  CartItemModel({
    required this.product,
    required this.quantity,
  });

  double get subtotal => product.price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'product_id': product.id,
      'product_name': product.name,
      'product_price': product.price,
      'product_image': product.images.isNotEmpty ? product.images.first : '',
      'category_id': product.categoryId,
      'brand': product.brand,
      'quantity': quantity,
    };
  }

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    final imageStr = map['product_image']?.toString() ?? '';
    return CartItemModel(
      product: ProductModel(
        id: map['product_id']?.toString() ?? '',
        name: map['product_name']?.toString() ?? 'Produk Komputer',
        description: '',
        descriptionId: '',
        price: (map['product_price'] as num?)?.toDouble() ?? 0,
        categoryId: map['category_id']?.toString() ?? '',
        brand: map['brand']?.toString() ?? '',
        images: imageStr.isNotEmpty ? [imageStr] : [],
        specs: {},
        rating: 0.0,
        reviewCount: 0,
        stock: 10,
        isNew: false,
        isOnSale: false,
      ),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}
