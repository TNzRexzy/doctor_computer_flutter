import 'dart:async';
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

  // Flash sale timer state comes from the Supabase `flash_sales` table.
  // Until it is loaded (or when no flash sale exists) the sale counts as ended.
  DateTime _flashSaleEndTime = DateTime.now();
  bool _isFlashSaleActive = false;
  RealtimeChannel? _flashSaleChannel;

  /// Only used as the end time of a NEW flash sale when no timer is running yet.
  static const Duration _defaultNewFlashSaleDuration = Duration(hours: 8);

  /// Naik setiap kali harga produk flash sale dikembalikan ke normal
  /// (timer berakhir). Dipakai `CartProvider` untuk menyegarkan harga keranjang.
  static final ValueNotifier<int> flashSaleExpired = ValueNotifier<int>(0);
  Timer? _flashSaleExpiryTimer;
  bool _isExpiringFlashSale = false;

  bool _isLoading = false;

  ProductProvider() {
    _loadData();
    _subscribeFlashSaleRealtime();
  }

  @override
  void dispose() {
    _flashSaleExpiryTimer?.cancel();
    final channel = _flashSaleChannel;
    if (channel != null) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  List<CategoryModel> get categories =>
      _categories.isNotEmpty ? _categories : mockCategories;
  List<ProductModel> get allProducts =>
      _allProducts.isNotEmpty ? _allProducts : mockProducts;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  bool get isLoading => _isLoading;
  DateTime get flashSaleEndTime => _flashSaleEndTime;
  bool get isFlashSaleActive => _isFlashSaleActive;

  /// `true` jika waktu flash sale sudah lewat (atau belum ada flash sale).
  bool get isFlashSaleExpired => !_flashSaleEndTime.isAfter(DateTime.now());

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
          return p.categoryId.toLowerCase().contains(
                selectedCat.name.toLowerCase(),
              ) ||
              p.name.toLowerCase().contains(selectedCat.name.toLowerCase());
        }
        return false;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where(
            (p) =>
                p.name.toLowerCase().contains(query) ||
                p.brand.toLowerCase().contains(query) ||
                p.description.toLowerCase().contains(query),
          )
          .toList();
    }

    result = result
        .where(
          (p) => p.price >= _priceRange.start && p.price <= _priceRange.end,
        )
        .toList();

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

      debugPrint(
        'Supabase categories count: ${catsRes.length}, products count: ${prodsRes.length}',
      );

      if (catsRes.isNotEmpty) {
        _categories = catsRes.map((c) {
          return CategoryModel(
            id: c['id']?.toString() ?? '',
            name: c['name']?.toString() ?? '',
            nameId: c['name_id']?.toString() ?? c['name']?.toString() ?? '',
            icon: _mapIcon(
              c['icon']?.toString() ?? '',
              id: c['id']?.toString() ?? '',
              name: c['name']?.toString() ?? '',
              nameId: c['name_id']?.toString() ?? '',
            ),
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
            specsMap = (p['specs'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
          }

          final price = (p['price'] as num?)?.toDouble() ?? 0.0;
          final origPrice = (p['original_price'] as num?)?.toDouble();
          final id = p['id']?.toString() ?? '';

          productMap[id] = ProductModel(
            id: id,
            name: p['name']?.toString() ?? '',
            description: p['description']?.toString() ?? '',
            descriptionId:
                p['description_id']?.toString() ??
                p['description']?.toString() ??
                '',
            price: price,
            originalPrice: origPrice != null && origPrice > 0
                ? origPrice
                : null,
            categoryId: p['category_id']?.toString() ?? '',
            brand: p['brand']?.toString() ?? 'Generic',
            images: images,
            specs: specsMap,
            rating: (p['rating'] as num?)?.toDouble() ?? 0.0,
            reviewCount: (p['review_count'] as num?)?.toInt() ?? 0,
            stock: (p['stock'] as num?)?.toInt() ?? 10,
            isNew: p['is_new'] as bool? ?? false,
            isOnSale:
                p['is_on_sale'] as bool? ??
                (origPrice != null && origPrice > price),
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
            // Rating & jumlah ulasan selalu dari database (dihitung dari reviews).
            final fromDb = productMap[prod.id];
            productMap[prod.id] = fromDb == null
                ? prod
                : prod.copyWith(
                    rating: fromDb.rating,
                    reviewCount: fromDb.reviewCount,
                  );
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
                categoryId:
                    overMap['category_id']?.toString() ?? existing.categoryId,
                description:
                    overMap['description']?.toString() ?? existing.description,
                descriptionId:
                    overMap['description']?.toString() ??
                    existing.descriptionId,
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

        // 5. Flash sale timer no longer lives in local cache (see
        // _loadFlashSaleConfig). Drop the legacy keys so they can't be reused.
        await prefs.remove(_prefFlashSaleEndTimeKey);
        await prefs.remove(_prefFlashSaleActiveKey);
      } catch (e) {
        debugPrint('Error applying product cache in ProductProvider: $e');
      }

      _allProducts = productMap.values.toList();

      // 6. Flash sale timer & status straight from Supabase
      await _loadFlashSaleConfig();
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

  /// Adds a catalog product in Supabase before updating the local display cache.
  Future<bool> addProduct(ProductModel product) async {
    final savedProduct = await supabase
        .from('products')
        .insert(product.toMap())
        .select('id, image_url')
        .single();
    _verifySavedImages(savedProduct, product);

    _allProducts.removeWhere((existing) => existing.id == product.id);
    _allProducts.insert(0, product);
    notifyListeners();

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

    return true;
  }

  /// Updates an existing product details, price, stock, or flash sale status.
  Future<bool> updateProduct(ProductModel product) async {
    final updatedRows = await supabase
        .from('products')
        .update(product.toMap())
        .eq('id', product.id)
        .select('id, image_url');
    if (updatedRows.isEmpty) {
      throw StateError(
        'Produk tidak ditemukan atau perubahan tidak diizinkan.',
      );
    }
    _verifySavedImages(updatedRows.first, product);

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

    return true;
  }

  void _verifySavedImages(Map<String, dynamic> savedRow, ProductModel product) {
    final savedImages = savedRow['image_url'];
    final images = savedImages is List
        ? savedImages.map((image) => image.toString()).toList()
        : savedImages is String && savedImages.isNotEmpty
        ? [savedImages]
        : <String>[];

    if (images.length != product.images.length ||
        !List.generate(
          images.length,
          (index) => images[index] == product.images[index],
        ).every((matches) => matches)) {
      throw StateError(
        'Database tidak menyimpan URL foto produk. Periksa tipe kolom '
        'products.image_url di Supabase.',
      );
    }
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

    final ok = await updateProduct(updated);
    if (ok) {
      await _syncFlashSaleRow(updated, isOnSale);
    }
    return ok;
  }

  /// Deletes a product from Supabase before removing it from local caches.
  Future<bool> deleteProduct(String productId) async {
    await supabase.from('products').delete().eq('id', productId);
    _allProducts.removeWhere((p) => p.id == productId);
    notifyListeners();

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

    return true;
  }

  // ============================================================
  // FLASH SALE (Supabase table: public.flash_sales)
  // ============================================================

  /// Reads the global flash sale timer from Supabase.
  /// End time = latest `ends_at`; active = at least one row has `is_active`.
  /// No rows => flash sale is treated as ended (no more hardcoded 8 hours).
  Future<void> _loadFlashSaleConfig() async {
    try {
      final List rows = await supabase
          .from('flash_sales')
          .select('ends_at, is_active')
          .order('ends_at', ascending: false);

      DateTime? latestEnd;
      bool anyActive = false;
      for (final row in rows) {
        final end = DateTime.tryParse(row['ends_at']?.toString() ?? '');
        if (end == null) continue;
        final localEnd = end.toLocal();
        if (latestEnd == null || localEnd.isAfter(latestEnd)) {
          latestEnd = localEnd;
        }
        if (row['is_active'] == true) anyActive = true;
      }

      _flashSaleEndTime = latestEnd ?? DateTime.now();
      _isFlashSaleActive = latestEnd != null && anyActive;
      notifyListeners();
      _scheduleFlashSaleExpiry();
    } catch (e) {
      debugPrint('Error loading flash sale config from Supabase: $e');
    }
  }

  // ------------------------------------------------------------
  // FLASH SALE EXPIRY: harga kembali normal saat timer berakhir
  // ------------------------------------------------------------

  /// Menjadwalkan pengembalian harga tepat saat timer berakhir. Jika timer
  /// sudah berakhir dan masih ada produk berstatus flash sale di perangkat
  /// ini, pengembalian dijalankan langsung.
  void _scheduleFlashSaleExpiry() {
    _flashSaleExpiryTimer?.cancel();
    final remaining = _flashSaleEndTime.difference(DateTime.now());
    if (remaining > Duration.zero) {
      // +2 detik: memberi toleransi selisih jam perangkat dan server.
      _flashSaleExpiryTimer = Timer(
        remaining + const Duration(seconds: 2),
        expireFlashSales,
      );
    } else if (_allProducts.any((p) => p.isOnSale)) {
      expireFlashSales();
    }
  }

  /// Memanggil RPC `expire_flash_sales`: produk dengan flash sale yang sudah
  /// berakhir kembali ke harga normal dan keluar dari flash sale (di database,
  /// sehingga keranjang/checkout juga memakai harga normal). Hasilnya
  /// diterapkan ke daftar produk, cache lokal admin/kasir, dan keranjang.
  Future<void> expireFlashSales() async {
    if (_isExpiringFlashSale) return;
    _isExpiringFlashSale = true;
    try {
      final res = await supabase.rpc('expire_flash_sales');
      final prices = <String, double>{};
      if (res is List) {
        for (final row in res) {
          if (row is Map && row['product_id'] != null) {
            prices[row['product_id'].toString()] =
                (row['price'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      // Cache lokal admin/kasir bisa masih menyimpan status flash sale lama.
      // Samakan dengan database untuk produk yang sudah tidak flash sale.
      if (isFlashSaleExpired) {
        final staleIds = _allProducts
            .where((p) => p.isOnSale && !prices.containsKey(p.id))
            .map((p) => p.id)
            .toList();
        if (staleIds.isNotEmpty) {
          final List rows = await supabase
              .from('products')
              .select('id, price, is_on_sale')
              .inFilter('id', staleIds);
          for (final row in rows) {
            if (row['is_on_sale'] == false) {
              prices[row['id'].toString()] =
                  (row['price'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }
      }

      if (prices.isEmpty) return;

      _allProducts = _allProducts.map((p) {
        final normalPrice = prices[p.id];
        return normalPrice == null ? p : _withoutSale(p, normalPrice);
      }).toList();
      notifyListeners();
      await _clearSaleFromLocalCache(prices);
      flashSaleExpired.value++;
    } catch (e) {
      debugPrint('Error expiring flash sales: $e');
    } finally {
      _isExpiringFlashSale = false;
    }
  }

  ProductModel _withoutSale(ProductModel p, double normalPrice) {
    return ProductModel(
      id: p.id,
      name: p.name,
      description: p.description,
      descriptionId: p.descriptionId,
      price: normalPrice,
      originalPrice: null,
      categoryId: p.categoryId,
      brand: p.brand,
      images: p.images,
      specs: p.specs,
      rating: p.rating,
      reviewCount: p.reviewCount,
      stock: p.stock,
      isNew: p.isNew,
      isOnSale: false,
    );
  }

  /// Menghapus harga/status flash sale dari cache lokal (override & produk
  /// custom) supaya tidak diterapkan kembali saat aplikasi dibuka lagi.
  Future<void> _clearSaleFromLocalCache(Map<String, double> prices) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final overridesJson = prefs.getString(_prefProductOverridesKey);
      if (overridesJson != null && overridesJson.isNotEmpty) {
        final overrides = Map<String, dynamic>.from(jsonDecode(overridesJson));
        var changed = false;
        for (final entry in prices.entries) {
          final current = overrides[entry.key];
          if (current is Map) {
            final map = Map<String, dynamic>.from(current);
            map['price'] = entry.value;
            map['original_price'] = null;
            map['is_on_sale'] = false;
            overrides[entry.key] = map;
            changed = true;
          }
        }
        if (changed) {
          await prefs.setString(_prefProductOverridesKey, jsonEncode(overrides));
        }
      }

      final customJson = prefs.getString(_prefCustomProductsKey);
      if (customJson != null && customJson.isNotEmpty) {
        final List list = jsonDecode(customJson);
        var changed = false;
        for (var i = 0; i < list.length; i++) {
          final item = list[i];
          if (item is Map && prices.containsKey(item['id']?.toString())) {
            final map = Map<String, dynamic>.from(item);
            map['price'] = prices[item['id'].toString()];
            map['original_price'] = null;
            map['is_on_sale'] = false;
            list[i] = map;
            changed = true;
          }
        }
        if (changed) {
          await prefs.setString(_prefCustomProductsKey, jsonEncode(list));
        }
      }
    } catch (e) {
      debugPrint('Error clearing flash sale from local cache: $e');
    }
  }

  /// Keeps every device in sync when the flash_sales table changes.
  void _subscribeFlashSaleRealtime() {
    try {
      _flashSaleChannel = supabase
          .channel('public:flash_sales')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'flash_sales',
            callback: (_) => _loadFlashSaleConfig(),
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to flash_sales realtime: $e');
    }
  }

  /// Creates / removes the flash_sales row of one product.
  Future<void> _syncFlashSaleRow(ProductModel product, bool isOnSale) async {
    try {
      if (isOnSale) {
        final now = DateTime.now();
        final timerRunning = _flashSaleEndTime.isAfter(now);
        final end = timerRunning
            ? _flashSaleEndTime
            : now.add(_defaultNewFlashSaleDuration);
        final active = timerRunning ? _isFlashSaleActive : true;

        await supabase.from('flash_sales').upsert({
          'product_id': product.id,
          'original_price': product.originalPrice ?? product.price,
          'flash_price': product.price,
          'flash_stock': product.stock,
          'ends_at': end.toUtc().toIso8601String(),
          'is_active': active,
          'created_by': supabase.auth.currentUser?.id,
          'updated_at': now.toUtc().toIso8601String(),
        }, onConflict: 'product_id');
      } else {
        await supabase
            .from('flash_sales')
            .delete()
            .eq('product_id', product.id);
      }
      await _loadFlashSaleConfig();
    } catch (e) {
      debugPrint('Error syncing flash sale row: $e');
    }
  }

  /// Saves the global flash sale end time/status to Supabase.
  /// Local state is updated first (instant UI) and rolled back on failure.
  Future<bool> _persistFlashSaleConfig({
    required DateTime endTime,
    required bool active,
  }) async {
    final previousEnd = _flashSaleEndTime;
    final previousActive = _isFlashSaleActive;
    _flashSaleEndTime = endTime;
    _isFlashSaleActive = active;
    notifyListeners();

    try {
      final endIso = endTime.toUtc().toIso8601String();
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final saleProducts = allProducts.where((p) => p.isOnSale).toList();

      // Make sure every product on sale has a row (covers legacy data).
      if (saleProducts.isNotEmpty) {
        await supabase.from('flash_sales').upsert(
          saleProducts
              .map(
                (p) => {
                  'product_id': p.id,
                  'original_price': p.originalPrice ?? p.price,
                  'flash_price': p.price,
                  'flash_stock': p.stock,
                  'ends_at': endIso,
                  'is_active': active,
                  'created_by': supabase.auth.currentUser?.id,
                },
              )
              .toList(),
          onConflict: 'product_id',
          ignoreDuplicates: true,
        );
      }

      final values = {
        'ends_at': endIso,
        'is_active': active,
        'updated_at': nowIso,
      };
      final List updated = saleProducts.isNotEmpty
          ? await supabase
                .from('flash_sales')
                .update(values)
                .inFilter('product_id', saleProducts.map((p) => p.id).toList())
                .select('id')
          : await supabase
                .from('flash_sales')
                .update(values)
                .not('id', 'is', null)
                .select('id');

      if (updated.isEmpty) {
        throw StateError('Tidak ada baris flash_sales yang berhasil diubah.');
      }
      _scheduleFlashSaleExpiry();
      return true;
    } catch (e) {
      debugPrint('Error saving flash sale config to Supabase: $e');
      _flashSaleEndTime = previousEnd;
      _isFlashSaleActive = previousActive;
      notifyListeners();
      return false;
    }
  }

  /// Updates Flash Sale end time and saves it to Supabase (realtime for all devices).
  Future<bool> updateFlashSaleTime(DateTime newEndTime) {
    return _persistFlashSaleConfig(
      endTime: newEndTime,
      active: newEndTime.isAfter(DateTime.now()),
    );
  }

  /// Sets whether Flash Sale is active or paused (saved to Supabase).
  Future<bool> setFlashSaleActive(bool active) {
    return _persistFlashSaleConfig(endTime: _flashSaleEndTime, active: active);
  }

  /// Aturan ikon kategori. Dicek berurutan; aturan pertama yang cocok menang.
  /// Kata dicocokkan per-token (mis. `ram` tidak cocok dengan `program`);
  /// kata >= 6 huruf juga cocok sebagai bagian dari token (mis. `processors`).
  static const List<MapEntry<List<String>, IconData>> _categoryIconRules = [
    MapEntry(['laptop', 'notebook', 'macbook'], Icons.laptop_mac),
    MapEntry(['desktop', 'aio'], Icons.desktop_windows),
    MapEntry(['monitor', 'display', 'screen', 'layar'], Icons.monitor),
    MapEntry(['keyboard', 'keyboards'], Icons.keyboard),
    MapEntry(['mouse', 'mice'], Icons.mouse),
    MapEntry(['speaker', 'speakers'], Icons.speaker),
    MapEntry(['headset', 'headphone', 'earphone', 'audio'], Icons.headset),
    MapEntry(['cpu', 'processor', 'prosesor'], Icons.memory),
    MapEntry([
      'gpu', 'vga', 'graphics', 'graphic', 'videocard', 'videogame',
    ], Icons.videogame_asset),
    MapEntry([
      'motherboard', 'mainboard', 'mobo', 'board',
    ], Icons.developer_board),
    MapEntry(['ram', 'dimm', 'ddr4', 'ddr5', 'sd'], Icons.sd_card),
    MapEntry(['ssd', 'nvme'], Icons.sd_storage),
    MapEntry([
      'storage', 'hdd', 'harddisk', 'hard', 'disk',
    ], Icons.storage),
    MapEntry(['psu', 'power', 'supply', 'powersupply'], Icons.power),
    MapEntry(['case', 'casing', 'chassis', 'inventory'], Icons.inventory_2),
    MapEntry([
      'cooler', 'cooling', 'fan', 'heatsink', 'radiator', 'ac',
    ], Icons.ac_unit),
    MapEntry([
      'router', 'network', 'networking', 'jaringan', 'wifi',
    ], Icons.router),
    MapEntry(['printer', 'print'], Icons.print),
    MapEntry(['webcam', 'camera', 'kamera'], Icons.videocam),
    MapEntry(['tablet'], Icons.tablet_mac),
    MapEntry(['smartphone', 'phone', 'handphone'], Icons.smartphone),
    MapEntry(['gaming', 'game', 'games'], Icons.sports_esports),
    MapEntry(['ups', 'battery'], Icons.battery_charging_full),
    MapEntry([
      'accessory', 'accessories', 'aksesoris', 'cable', 'kabel',
    ], Icons.extension),
    MapEntry([
      'peripheral', 'peripherals', 'periph',
    ], Icons.devices_other),
    // Terakhir: nama ikon Material "memory" (chip) pada kolom icon.
    MapEntry(['memory', 'chip'], Icons.memory),
  ];

  static IconData? _iconForText(String text) {
    final tokens = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;
    for (final rule in _categoryIconRules) {
      for (final keyword in rule.key) {
        for (final token in tokens) {
          if (token == keyword ||
              (keyword.length >= 6 && token.contains(keyword))) {
            return rule.value;
          }
        }
      }
    }
    return null;
  }

  /// Memilih ikon kategori. Urutan prioritas: id, nama, nama Indonesia, lalu
  /// kolom `icon`, sehingga CPU, GPU, RAM, dst. mendapat ikon masing-masing
  /// walau kolom `icon` di database sama atau generik.
  IconData _mapIcon(
    String iconName, {
    String id = '',
    String name = '',
    String nameId = '',
  }) {
    for (final text in [id, name, nameId, iconName]) {
      final icon = _iconForText(text);
      if (icon != null) return icon;
    }
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
