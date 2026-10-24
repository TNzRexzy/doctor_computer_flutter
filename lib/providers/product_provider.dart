import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/models/category_model.dart';
import 'package:doctor_computer/data/mock/mock_categories.dart';
import 'package:doctor_computer/data/mock/mock_products.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/core/constants/app_images.dart';

class ProductProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  static const String _prefCustomProductsKey = 'admin_custom_products';
  static const String _prefProductOverridesKey = 'admin_product_overrides';
  static const String _prefDeletedProductsKey = 'admin_deleted_products';
  static const String _prefFlashSaleEndTimeKey = 'flash_sale_end_time';
  static const String _prefFlashSaleActiveKey = 'flash_sale_is_active';

  String? _selectedCategoryId;
  String _searchQuery = '';
  String _sortBy = 'popular';
  RangeValues _priceRange = const RangeValues(0, 50000000);
  final List<String> _selectedBrands = [];

  List<CategoryModel> _categories = [];
  List<ProductModel> _allProducts = [];

  DateTime _flashSaleEndTime = DateTime.now().add(const Duration(hours: 8));
  bool _isFlashSaleActive = true;

  bool _isLoading = false;

  ProductProvider() {
    _loadData();
  }

  List<CategoryModel> get categories => _categories.isNotEmpty ? _categories : mockCategories;
  List<ProductModel> get allProducts => _allProducts.isNotEmpty ? _allProducts : mockProducts;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  bool get isLoading => _isLoading;
  DateTime get flashSaleEndTime => _flashSaleEndTime;
  bool get isFlashSaleActive => _isFlashSaleActive;

  Duration get flashSaleRemainingTime {
    final now = DateTime.now();
    if (_flashSaleEndTime.isAfter(now) && _isFlashSaleActive) {
      return _flashSaleEndTime.difference(now);
    }
    return Duration.zero;
  }

  List<ProductModel> get filteredProducts {
    List<ProductModel> result = List<ProductModel>.from(allProducts);

    if (_selectedCategoryId != null) {
      result = result.where((p) {
        if (p.categoryId == _selectedCategoryId) return true;
        final selectedCat = categories.cast<CategoryModel?>().firstWhere(
              (c) => c?.id == _selectedCategoryId,
              orElse: () => null,
            );
        if (selectedCat != null) {
          return p.categoryId.toLowerCase().contains(selectedCat.name.toLowerCase()) ||
              p.name.toLowerCase().contains(selectedCat.name.toLowerCase());
        }
        return false;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) =>
          p.name.toLowerCase().contains(query) ||
          p.brand.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query)
      ).toList();
    }

    result = result.where((p) =>
        p.price >= _priceRange.start && p.price <= _priceRange.end
    ).toList();

    if (_selectedBrands.isNotEmpty) {
      result = result.where((p) => _selectedBrands.contains(p.brand)).toList();
    }

    switch (_sortBy) {
      case 'price_low':
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      default:
        result.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    }

    return result;
  }

  List<ProductModel> get flashDeals =>
      allProducts.where((p) => p.isOnSale).take(10).toList();

  List<ProductModel> get newArrivals =>
      allProducts.where((p) => p.isNew).take(10).toList();

  List<ProductModel> get bestSellers {
    final sorted = List<ProductModel>.from(allProducts);
    sorted.sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(10).toList();
  }

  List<String> get availableBrands {
    final products = _selectedCategoryId != null
        ? allProducts.where((p) => p.categoryId == _selectedCategoryId).toList()
        : allProducts;
    return products.map((p) => p.brand).toSet().toList();
  }

  Future<void> reloadData() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('Fetching categories & products from Supabase...');
      final List catsRes = await supabase.from('categories').select();
      final List prodsRes = await supabase.from('products').select();

      debugPrint('Supabase categories count: ${catsRes.length}, products count: ${prodsRes.length}');

      if (catsRes.isNotEmpty) {
        _categories = catsRes.map((c) {
          return CategoryModel(
            id: c['id']?.toString() ?? '',
            name: c['name']?.toString() ?? '',
            nameId: c['name_id']?.toString() ?? c['name']?.toString() ?? '',
            icon: _mapIcon(c['icon']?.toString() ?? c['name']?.toString() ?? ''),
            productCount: (c['product_count'] as num? ?? 0).toInt(),
          );
        }).toList();
      } else {
        _categories = List.from(mockCategories);
      }

      final Map<String, ProductModel> productMap = {};

      // 1. Initial products from Supabase or mock
      if (prodsRes.isNotEmpty) {
        for (final p in prodsRes) {
          final rawImages = p['image_url'];
          final List<String> images = AppImages.resolveProductImages(
            rawImages,
            p['id']?.toString() ?? '',
            productName: p['name']?.toString() ?? '',
            categoryId: p['category_id']?.toString(),
            brand: p['brand']?.toString(),
          );

          Map<String, String> specsMap = {};
          if (p['specs'] is Map) {
            specsMap = (p['specs'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
          }

          final price = (p['price'] as num?)?.toDouble() ?? 0.0;
          final origPrice = (p['original_price'] as num?)?.toDouble();
          final id = p['id']?.toString() ?? '';

          productMap[id] = ProductModel(
            id: id,
            name: p['name']?.toString() ?? '',
            description: p['description']?.toString() ?? '',
            descriptionId: p['description_id']?.toString() ?? p['description']?.toString() ?? '',
            price: price,
            originalPrice: origPrice != null && origPrice > 0 ? origPrice : null,
            categoryId: p['category_id']?.toString() ?? '',
            brand: p['brand']?.toString() ?? 'Generic',
            images: images,
            specs: specsMap,
            rating: (p['rating'] as num?)?.toDouble() ?? 4.5,
            reviewCount: (p['review_count'] as num?)?.toInt() ?? 10,
            stock: (p['stock'] as num?)?.toInt() ?? 10,
            isNew: p['is_new'] as bool? ?? false,
            isOnSale: p['is_on_sale'] as bool? ?? (origPrice != null && origPrice > price),
          );
        }
      } else {
        for (final p in mockProducts) {
          productMap[p.id] = p;
        }
      }

      // 2. Merge local custom products from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final customJson = prefs.getString(_prefCustomProductsKey);
        if (customJson != null && customJson.isNotEmpty) {
          final List list = jsonDecode(customJson);
          for (final item in list) {
            final prod = ProductModel.fromMap(item as Map<String, dynamic>);
            productMap[prod.id] = prod;
          }
        }

        // 3. Apply product overrides (flash sale, price, stock edits)
        final overridesJson = prefs.getString(_prefProductOverridesKey);
        if (overridesJson != null && overridesJson.isNotEmpty) {
          final Map<String, dynamic> overrides = jsonDecode(overridesJson);
          for (final entry in overrides.entries) {
            final pid = entry.key;
            if (productMap.containsKey(pid)) {
              final overMap = entry.value as Map<String, dynamic>;
              final existing = productMap[pid]!;
              productMap[pid] = existing.copyWith(
                name: overMap['name']?.toString() ?? existing.name,
                price: (overMap['price'] as num?)?.toDouble() ?? existing.price,
                originalPrice: overMap.containsKey('original_price')
                    ? (overMap['original_price'] as num?)?.toDouble()
                    : existing.originalPrice,
                stock: (overMap['stock'] as num?)?.toInt() ?? existing.stock,
                isOnSale: overMap['is_on_sale'] as bool? ?? existing.isOnSale,
                brand: overMap['brand']?.toString() ?? existing.brand,
                categoryId: overMap['category_id']?.toString() ?? existing.categoryId,
                description: overMap['description']?.toString() ?? existing.description,
                descriptionId: overMap['description']?.toString() ?? existing.descriptionId,
              );
            }
          }
        }

        // 4. Remove deleted products
        final deletedJson = prefs.getString(_prefDeletedProductsKey);
        if (deletedJson != null && deletedJson.isNotEmpty) {
          final List deletedList = jsonDecode(deletedJson);
          for (final id in deletedList) {
            productMap.remove(id.toString());
          }
        }

        // 5. Load flash sale timer config
        final endTimeStr = prefs.getString(_prefFlashSaleEndTimeKey);
        if (endTimeStr != null && endTimeStr.isNotEmpty) {
          final parsed = DateTime.tryParse(endTimeStr);
          if (parsed != null) {
            _flashSaleEndTime = parsed;
          }
        }
        _isFlashSaleActive = prefs.getBool(_prefFlashSaleActiveKey) ?? true;
      } catch (e) {
        debugPrint('Error applying product cache in ProductProvider: $e');
      }

      _allProducts = productMap.values.toList();
    } catch (e) {
      debugPrint('Error loading Supabase products: $e');
      if (_categories.isEmpty) _categories = List.from(mockCategories);
      if (_allProducts.isEmpty) _allProducts = List.from(mockProducts);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // ADMIN & CASHIER PRODUCT MANAGEMENT
  // ============================================================

  /// Adds a new product to the catalog, caches locally, and syncs to Supabase.
  Future<bool> addProduct(ProductModel product) async {
    _allProducts.insert(0, product);
    notifyListeners();

    // 1. Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      List<dynamic> customList = [];
      final existingJson = prefs.getString(_prefCustomProductsKey);
      if (existingJson != null && existingJson.isNotEmpty) {
        customList = jsonDecode(existingJson);
      }
      customList.removeWhere((item) => item['id'] == product.id);
      customList.insert(0, product.toMap());
      await prefs.setString(_prefCustomProductsKey, jsonEncode(customList));
    } catch (e) {
      debugPrint('Error caching new product: $e');
    }

    // 2. Sync to Supabase products table
    try {
      await supabase.from('products').insert(product.toMap());
    } catch (e) {
      debugPrint('Supabase add product notice: $e');
    }

    return true;
  }

  /// Updates an existing product details, price, stock, or flash sale status.
  Future<bool> updateProduct(ProductModel product) async {
    final index = _allProducts.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _allProducts[index] = product;
    } else {
      _allProducts.insert(0, product);
    }
    notifyListeners();

    // 1. Save override to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> overrides = {};
      final existingJson = prefs.getString(_prefProductOverridesKey);
      if (existingJson != null && existingJson.isNotEmpty) {
        overrides = Map<String, dynamic>.from(jsonDecode(existingJson));
      }
      overrides[product.id] = product.toMap();
      await prefs.setString(_prefProductOverridesKey, jsonEncode(overrides));
    } catch (e) {
      debugPrint('Error caching product update: $e');
    }

    // 2. Sync to Supabase products table
    try {
      await supabase.from('products').update(product.toMap()).eq('id', product.id);
    } catch (e) {
      debugPrint('Supabase update product notice: $e');
    }

    return true;
  }

  /// Toggles Flash Sale on a product with optional sale price and original price.
  Future<bool> toggleFlashSale(
    String productId,
    bool isOnSale, {
    double? salePrice,
    double? originalPrice,
  }) async {
    final prod = getProductById(productId);
    if (prod == null) return false;

    double newPrice = prod.price;
    double? newOrigPrice = prod.originalPrice;

    if (isOnSale) {
      if (salePrice != null && salePrice > 0) {
        newPrice = salePrice;
        newOrigPrice = originalPrice ?? (prod.originalPrice ?? prod.price);
      } else if (newOrigPrice == null || newOrigPrice <= prod.price) {
        // Default 20% discount if not specified
        newOrigPrice = prod.price;
        newPrice = prod.price * 0.8;
      }
    } else {
      // Revert from flash sale
      if (prod.originalPrice != null && prod.originalPrice! > prod.price) {
        newPrice = prod.originalPrice!;
        newOrigPrice = null;
      }
    }

    final updated = prod.copyWith(
      isOnSale: isOnSale,
      price: newPrice,
      originalPrice: newOrigPrice,
    );

    return await updateProduct(updated);
  }

  /// Deletes a product from local memory, cache, and Supabase.
  Future<bool> deleteProduct(String productId) async {
    _allProducts.removeWhere((p) => p.id == productId);
    notifyListeners();

    // 1. Update SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove from custom products
      final customJson = prefs.getString(_prefCustomProductsKey);
      if (customJson != null && customJson.isNotEmpty) {
        final List customList = jsonDecode(customJson);
        customList.removeWhere((item) => item['id'] == productId);
        await prefs.setString(_prefCustomProductsKey, jsonEncode(customList));
      }
      // Add to deleted products list
      List<dynamic> deletedList = [];
      final delJson = prefs.getString(_prefDeletedProductsKey);
      if (delJson != null && delJson.isNotEmpty) {
        deletedList = jsonDecode(delJson);
      }
      if (!deletedList.contains(productId)) {
        deletedList.add(productId);
      }
      await prefs.setString(_prefDeletedProductsKey, jsonEncode(deletedList));
    } catch (e) {
      debugPrint('Error updating deleted products cache: $e');
    }

    // 2. Sync to Supabase
    try {
      await supabase.from('products').delete().eq('id', productId);
    } catch (e) {
      debugPrint('Supabase delete product notice: $e');
    }

    return true;
  }

  /// Decrements stock for a product after purchase
  Future<void> decrementStock(String productId, int quantity) async {
    final index = _allProducts.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    final product = _allProducts[index];
    final newStock = (product.stock - quantity).clamp(0, 999999);
    final updated = product.copyWith(stock: newStock);
    _allProducts[index] = updated;
    notifyListeners();

    // 1. Update SharedPreferences overrides
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> overrides = {};
      final existingJson = prefs.getString(_prefProductOverridesKey);
      if (existingJson != null && existingJson.isNotEmpty) {
        overrides = Map<String, dynamic>.from(jsonDecode(existingJson));
      }
      final currentMap = overrides[productId] != null
          ? Map<String, dynamic>.from(overrides[productId] as Map)
          : updated.toMap();
      currentMap['stock'] = newStock;
      overrides[productId] = currentMap;
      await prefs.setString(_prefProductOverridesKey, jsonEncode(overrides));
    } catch (e) {
      debugPrint('Error caching stock decrement: $e');
    }

    // 2. Sync to Supabase
    try {
      await supabase.from('products').update({'stock': newStock}).eq('id', productId);
    } catch (e) {
      debugPrint('Supabase stock decrement notice: $e');
    }
  }

  /// Updates Flash Sale end time in real-time and persists it across sessions.
  Future<void> updateFlashSaleTime(DateTime newEndTime) async {
    _flashSaleEndTime = newEndTime;
    _isFlashSaleActive = newEndTime.isAfter(DateTime.now());
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefFlashSaleEndTimeKey, newEndTime.toIso8601String());
      await prefs.setBool(_prefFlashSaleActiveKey, _isFlashSaleActive);
    } catch (e) {
      debugPrint('Error saving flash sale timer settings: $e');
    }
  }

  /// Sets whether Flash Sale is active or paused.
  Future<void> setFlashSaleActive(bool active) async {
    _isFlashSaleActive = active;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefFlashSaleActiveKey, active);
    } catch (e) {
      debugPrint('Error saving flash sale active flag: $e');
    }
  }

  IconData _mapIcon(String iconName) {
    final lower = iconName.toLowerCase();
    if (lower.contains('laptop')) return Icons.laptop_mac;
    if (lower.contains('desktop') || lower.contains('periph')) return Icons.desktop_windows;
    if (lower.contains('monitor')) return Icons.monitor;
    if (lower.contains('keyboard')) return Icons.keyboard;
    if (lower.contains('mouse')) return Icons.mouse;
    if (lower.contains('headset') || lower.contains('audio')) return Icons.headset;
    if (lower.contains('storage') || lower.contains('ssd')) return Icons.storage;
    if (lower.contains('router') || lower.contains('network')) return Icons.router;
    if (lower.contains('cpu')) return Icons.memory;
    if (lower.contains('gpu')) return Icons.videogame_asset;
    if (lower.contains('motherboard')) return Icons.developer_board;
    if (lower.contains('ram')) return Icons.sd_card;
    if (lower.contains('case')) return Icons.inventory_2;
    if (lower.contains('cooler')) return Icons.ac_unit;
    return Icons.category;
  }

  ProductModel? getProductById(String id) {
    try {
      return allProducts.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  void setCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    _selectedBrands.clear();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void setPriceRange(RangeValues range) {
    _priceRange = range;
    notifyListeners();
  }

  void toggleBrand(String brand) {
    if (_selectedBrands.contains(brand)) {
      _selectedBrands.remove(brand);
    } else {
      _selectedBrands.add(brand);
    }
    notifyListeners();
  }

  void clearFilters() {
    _selectedCategoryId = null;
    _searchQuery = '';
    _sortBy = 'popular';
    _priceRange = const RangeValues(0, 50000000);
    _selectedBrands.clear();
    notifyListeners();
  }
}
