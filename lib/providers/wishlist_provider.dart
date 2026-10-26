import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/mock/mock_products.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WishlistProvider extends ChangeNotifier {
  final List<ProductModel> _items = [];
  String? _userId;

  List<ProductModel> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;

  String? get userId => _userId;
  set userId(String? id) {
    _userId = id;
    _syncWishlistFromDb();
    notifyListeners();
  }

  final supabase = Supabase.instance.client;

  WishlistProvider() {
    // Initial setup
  }

  void setUserId(String? id) {
    _userId = id;
    _syncWishlistFromDb();
    notifyListeners();
  }

  Future<void> _syncWishlistFromDb() async {
    if (_userId == null) {
      notifyListeners();
      return;
    }

    try {
      final List res = await supabase
          .from('wishlist')
          .select()
          .eq('user_id', _userId!);

      _items.clear();
      for (var item in res) {
        final map = item as Map<String, dynamic>;
        final productId = map['product_id']?.toString();
        if (productId == null) continue;
        final product = await _fetchProductAsync(productId);
        if (product != null) {
          _items.add(product);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
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
          rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
          reviewCount: (data['review_count'] as num?)?.toInt() ?? 0,
          stock: (data['stock'] as num?)?.toInt() ?? 10,
          isNew: data['is_new'] as bool? ?? false,
          isOnSale: data['is_on_sale'] as bool? ?? false,
        );
      }
    } catch (e) {
      debugPrint('Error fetching product for wishlist: $e');
    }

    try {
      return mockProducts.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  bool isInWishlist(String productId) {
    return _items.any((item) => item.id == productId);
  }

  void toggleWishlist(ProductModel product) {
    if (isInWishlist(product.id)) {
      _items.removeWhere((item) => item.id == product.id);
      notifyListeners();
      _removeFromWishlistDb(product.id);
    } else {
      _items.add(product);
      notifyListeners();
      _addToWishlistDb(product);
    }
  }

  Future<void> _addToWishlistDb(ProductModel product) async {
    if (_userId == null) return;
    try {
      await supabase.from('wishlist').upsert({
        'user_id': _userId!,
        'product_id': product.id,
      }, onConflict: 'user_id,product_id');
    } catch (e) {
      debugPrint('Error adding to wishlist db: $e');
    }
  }

  Future<void> _removeFromWishlistDb(String productId) async {
    if (_userId == null) return;
    try {
      await supabase
          .from('wishlist')
          .delete()
          .eq('user_id', _userId!)
          .eq('product_id', productId);
    } catch (e) {
      debugPrint('Error removing from wishlist db: $e');
    }
  }
}
