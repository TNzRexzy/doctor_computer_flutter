import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/product_model.dart';

class WishlistProvider extends ChangeNotifier {
  final List<ProductModel> _items = [];

  List<ProductModel> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;

  bool isInWishlist(String productId) {
    return _items.any((item) => item.id == productId);
  }

  void toggleWishlist(ProductModel product) {
    if (isInWishlist(product.id)) {
      _items.removeWhere((item) => item.id == product.id);
    } else {
      _items.add(product);
    }
    notifyListeners();
  }

  void removeFromWishlist(String productId) {
    _items.removeWhere((item) => item.id == productId);
    notifyListeners();
  }
}
