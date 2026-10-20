import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/mock/mock_products.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  String? _userId;

  List<CartItemModel> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice => _items.fold(0, (sum, item) => sum + item.subtotal);

  String? get userId => _userId;
  set userId(String? id) {
    _userId = id;
    _syncCartFromDb();
    notifyListeners();
  }

  final supabase = Supabase.instance.client;

  CartProvider() {
    // Initial setup
  }

  void setUserId(String? id) {
    _userId = id;
    _syncCartFromDb();
    notifyListeners();
  }

  Future<void> _syncCartFromDb() async {
    if (_userId == null) {
      notifyListeners();
      return;
    }

    try {
      final List res = await supabase
          .from('cart_items')
          .select()
          .eq('user_id', _userId!);

      _items.clear();
      for (var item in res) {
        final map = item as Map<String, dynamic>;
        final productId = map['product_id']?.toString();
        if (productId == null) continue;
        final qty = (map['quantity'] as num? ?? 1).toInt();
        final product = await _fetchProductAsync(productId);
        if (product != null) {
          _items.add(CartItemModel(product: product, quantity: qty));
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cart from db: $e');
    }
  }

  Future<ProductModel?> _fetchProductAsync(String productId) async {
    try {
      final data = await supabase
          .from('products')
          .select()
          .eq('id', productId)
          .maybeSingle();

      if (data != null) {
        final rawImages = data['image_url'];
        List<String> images = [];
        if (rawImages is List) {
          images = rawImages.map((e) => e.toString()).toList();
        } else if (rawImages is String && rawImages.isNotEmpty) {
          images = [rawImages];
        }

        return ProductModel(
          id: data['id']?.toString() ?? productId,
          name: data['name']?.toString() ?? '',
          description: data['description']?.toString() ?? '',
          descriptionId: data['description_id']?.toString() ?? '',
          price: (data['price'] as num?)?.toDouble() ?? 0.0,
          originalPrice: (data['original_price'] as num?)?.toDouble(),
          categoryId: data['category_id']?.toString() ?? '',
          brand: data['brand']?.toString() ?? '',
          images: images,
          specs: Map<String, String>.from(data['specs'] as Map? ?? {}),
          rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
          reviewCount: (data['review_count'] as num?)?.toInt() ?? 10,
          stock: (data['stock'] as num?)?.toInt() ?? 10,
          isNew: data['is_new'] as bool? ?? false,
          isOnSale: data['is_on_sale'] as bool? ?? false,
        );
      }
    } catch (e) {
      debugPrint('Error fetching product from Supabase: $e');
    }

    // Fallback to mock product
    try {
      return mockProducts.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  Future<void> addToCart(ProductModel product, {int quantity = 1}) async {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItemModel(product: product, quantity: quantity));
    }
    notifyListeners();

    if (_userId != null) {
      try {
        await supabase.from('cart_items').upsert({
          'user_id': _userId!,
          'product_id': product.id,
          'quantity': existingIndex >= 0 ? _items[existingIndex].quantity : quantity,
        }, onConflict: 'user_id,product_id');
      } catch (e) {
        debugPrint('Error persisting cart item to db: $e');
      }
    }
  }

  Future<void> removeFromCart(String productId) async {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();

    if (_userId != null) {
      try {
        await supabase
            .from('cart_items')
            .delete()
            .eq('user_id', _userId!)
            .eq('product_id', productId);
      } catch (e) {
        debugPrint('Error removing from cart db: $e');
      }
    }
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(productId);
      return;
    }

    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
    }

    if (_userId != null) {
      try {
        await supabase
            .from('cart_items')
            .update({'quantity': quantity})
            .eq('user_id', _userId!)
            .eq('product_id', productId);
      } catch (e) {
        debugPrint('Error updating quantity in db: $e');
      }
    }
  }

  Future<void> clearCart() async {
    _items.clear();
    notifyListeners();

    if (_userId != null) {
      try {
        await supabase
            .from('cart_items')
            .delete()
            .eq('user_id', _userId!);
      } catch (e) {
        debugPrint('Error clearing cart in db: $e');
      }
    }
  }

  bool isInCart(String productId) {
    return _items.any((item) => item.product.id == productId);
  }
}
