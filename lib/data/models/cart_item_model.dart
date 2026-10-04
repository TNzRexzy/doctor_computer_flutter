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
}
