import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/models/flash_sale_model.dart';
import 'package:doctor_computer/data/models/category_model.dart';
import 'package:doctor_computer/data/models/brand_model.dart';
import 'package:doctor_computer/data/models/product_subtype_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/core/constants/app_images.dart';

class ProductProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  static const String _prefCustomProductsKey = 'admin_custom_products';
  static const String _prefProductOverridesKey = 'admin_product_overrides';
  static const String _prefDeletedProductsKey = 'admin_deleted_products';

  String? _selectedCategoryId;
  String _searchQuery = '';
  String _sortBy = 'popular';
  RangeValues _priceRange = const RangeValues(0, 50000000);
  final List<String> _selectedBrands = [];

  List<CategoryModel> _categories = [];
  List<ProductModel> _allProducts = [];
  List<BrandModel> _brands = [];
  List<ProductSubtypeModel> _subtypes = [];

  // Flash sales come from the `flash_sales` table (Supabase).
  List<FlashSaleModel> _flashSales = [];
  Timer? _flashBoundaryTimer; // fires when a sale starts/ends
  Timer? _flashPollTimer; // periodic refresh from the database

  bool _isLoading = false;

  ProductProvider() {
    _loadData();
    _flashPollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => reloadFlashSales(),
    );
  }

  @override
  void dispose() {
    _flashBoundaryTimer?.cancel();
    _flashPollTimer?.cancel();
    super.dispose();
  }

  List<CategoryModel> get categories => _categories;
  List<ProductModel> get allProducts => _allProducts;
  List<BrandModel> get brands => _brands;
  List<ProductSubtypeModel> get subtypes => _subtypes;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  bool get isLoading => _isLoading;

  /// All flash sale rows (any status) - used by the admin/cashier panel.
  List<FlashSaleModel> get flashSales => List.unmodifiable(_flashSales);

  List<FlashSaleModel> get runningFlashSales {
    final now = DateTime.now();
    return _flashSales.where((s) => s.isRunningAt(now)).toList();
  }

  /// True when at least one flash sale is running right now.
  bool get isFlashSaleActive => runningFlashSales.isNotEmpty;

  /// The nearest end time among running flash sales.
  DateTime get flashSaleEndTime {
    final running = runningFlashSales;
    if (running.isEmpty) return DateTime.now();
    return running.map((s) => s.endsAt).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  Duration get flashSaleRemainingTime {
    if (!isFlashSaleActive) return Duration.zero;
    final d = flashSaleEndTime.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// The current (running or scheduled) flash sale of a product, if any.
  FlashSaleModel? flashSaleForProduct(String productId) {
    final now = DateTime.now();
    for (final s in _flashSales) {
      if (s.productId != productId) continue;
      final st = s.statusAt(now);
      if (st == FlashSaleStatus.running ||
          st == FlashSaleStatus.scheduled ||
          st == FlashSaleStatus.soldOut) {
        return s;
      }
    }
    return null;
  }

  bool isInFlashSale(String productId) =>
      allProducts.any((p) => p.id == productId && p.isFlashSale);

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
      allProducts.where((p) => p.isFlashSale).take(10).toList();

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
        _categories = [];
      }

      // Fetch brands from Supabase
      try {
        final List brandsRes = await supabase.from('brands').select();
        if (brandsRes.isNotEmpty) {
          _brands = brandsRes.map((b) => BrandModel.fromMap(b as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('Notice loading brands: $e');
      }

      // Fetch product subtypes from Supabase
      try {
        final List subtypesRes = await supabase.from('product_subtypes').select();
        if (subtypesRes.isNotEmpty) {
          _subtypes = subtypesRes.map((s) => ProductSubtypeModel.fromMap(s as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('Notice loading product_subtypes: $e');
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
            isOnSale: false, // flash status comes from `flash_sales`
            sku: p['sku']?.toString(),
            brandCode: p['brand_code']?.toString(),
            subtype: p['subtype']?.toString(),
            createdAt: p['created_at'] != null ? DateTime.tryParse(p['created_at'].toString()) : null,
            updatedAt: p['updated_at'] != null ? DateTime.tryParse(p['updated_at'].toString()) : null,
          );
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
              // Legacy overrides saved while a flash sale was baked into the
              // price are ignored for price fields (flash sales now live in DB).
              final legacyFlash = overMap['is_on_sale'] == true;
              productMap[pid] = existing.copyWith(
                name: overMap['name']?.toString() ?? existing.name,
                price: legacyFlash
                    ? existing.price
                    : (overMap['price'] as num?)?.toDouble() ?? existing.price,
                originalPrice: legacyFlash
                    ? existing.originalPrice
                    : overMap.containsKey('original_price')
                        ? (overMap['original_price'] as num?)?.toDouble()
                        : existing.originalPrice,
                stock: (overMap['stock'] as num?)?.toInt() ?? existing.stock,
                isOnSale: false,
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
      } catch (e) {
        debugPrint('Error applying product cache in ProductProvider: $e');
      }

      _allProducts = productMap.values
          .map((p) => p.isOnSale ? p.copyWith(isOnSale: false) : p)
          .toList();

      // 5. Flash sales from the database
      await _fetchFlashSales();
      _applyFlashSales(notify: false);
    } catch (e) {
      debugPrint('Error loading Supabase products: $e');
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

    // 3. Count the sale against the flash sale quota
    if (product.isFlashSale) {
      try {
        await supabase.rpc('increment_flash_sale_sold', params: {
          'p_product_id': productId,
          'p_qty': quantity,
        });
        await reloadFlashSales();
      } catch (e) {
        debugPrint('Flash sale sold_count notice: $e');
      }
    }
  }

  // ============================================================
  // FLASH SALES (table: flash_sales)
  // ============================================================

  Future<void> _fetchFlashSales() async {
    try {
      final List res = await supabase
          .from('flash_sales')
          .select()
          .order('created_at', ascending: false);
      _flashSales = res
          .map((e) => FlashSaleModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error loading flash_sales (run 20261023_flash_sales.sql?): $e');
    }
  }

  /// Re-fetches flash sales from Supabase and re-applies them to products.
  Future<void> reloadFlashSales() async {
    await _fetchFlashSales();
    _applyFlashSales();
  }

  /// Merges currently running flash sales into the product list and schedules
  /// the next start/end boundary so the UI flips without a network call.
  void _applyFlashSales({bool notify = true}) {
    final now = DateTime.now();
    final running = <String, FlashSaleModel>{};
    for (final s in _flashSales) {
      if (!s.isRunningAt(now)) continue;
      final cur = running[s.productId];
      if (cur == null || s.endsAt.isBefore(cur.endsAt)) running[s.productId] = s;
    }

    _allProducts = _allProducts.map((p) {
      final sale = running[p.id];
      final base = p.withoutFlash();
      if (sale != null && sale.flashPrice < base.price) return base.withFlash(sale);
      return base;
    }).toList();

    _flashBoundaryTimer?.cancel();
    DateTime? next;
    for (final s in _flashSales) {
      if (!s.isActive) continue;
      for (final t in [s.startsAt, s.endsAt]) {
        if (t.isAfter(now) && (next == null || t.isBefore(next))) next = t;
      }
    }
    if (next != null) {
      _flashBoundaryTimer = Timer(
        next.difference(now) + const Duration(seconds: 1),
        () => _applyFlashSales(),
      );
    }
    if (notify) notifyListeners();
  }

  String _flashError(Object e) {
    if (e is PostgrestException) {
      if (e.code == '23505') return 'Produk ini sudah punya flash sale aktif. Akhiri dulu yang lama.';
      if (e.code == '42501') return 'Tidak ada izin. Login dengan akun admin/kasir yang terdaftar di Supabase.';
      if (e.code == '42P01' || e.code == 'PGRST205') {
        return 'Tabel flash_sales belum ada. Jalankan supabase/migrations/20261023_flash_sales.sql.';
      }
      return e.message;
    }
    return e.toString();
  }

  /// Creates (id == null) or updates a flash sale. Returns an error message,
  /// or null on success. Only touches `flash_sales`, never `products.price`.
  Future<String?> saveFlashSale({
    String? id,
    required String productId,
    required double flashPrice,
    required int flashStock,
    required DateTime startsAt,
    required DateTime endsAt,
    bool isActive = true,
  }) async {
    final product = getProductById(productId);
    if (product == null) return 'Produk tidak ditemukan.';
    final normalPrice = product.basePrice;

    if (flashPrice <= 0 || flashPrice >= normalPrice) {
      return 'Harga flash harus lebih kecil dari harga normal.';
    }
    if (flashStock <= 0) return 'Kuota flash sale minimal 1.';
    if (flashStock > product.stock) {
      return 'Kuota ($flashStock) melebihi stok produk (${product.stock}).';
    }
    if (!endsAt.isAfter(startsAt)) return 'Waktu selesai harus setelah waktu mulai.';
    if (!endsAt.isAfter(DateTime.now())) return 'Waktu selesai sudah lewat.';
    if (supabase.auth.currentUser == null) {
      return 'Sesi Supabase tidak ditemukan. Login ulang dengan akun staff.';
    }

    try {
      final data = {
        'flash_price': flashPrice,
        'original_price': normalPrice,
        'flash_stock': flashStock,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'is_active': isActive,
      };
      List rows;
      if (id == null) {
        // Close leftovers that already expired but are still flagged active.
        await supabase
            .from('flash_sales')
            .update({'is_active': false})
            .eq('product_id', productId)
            .eq('is_active', true)
            .lt('ends_at', DateTime.now().toUtc().toIso8601String());
        rows = await supabase.from('flash_sales').insert({
          'product_id': productId,
          'created_by': supabase.auth.currentUser?.id,
          ...data,
        }).select();
      } else {
        final existing = _flashSales.where((s) => s.id == id).toList();
        if (existing.isNotEmpty && flashStock < existing.first.soldCount) {
          return 'Kuota tidak boleh di bawah jumlah terjual (${existing.first.soldCount}).';
        }
        rows = await supabase.from('flash_sales').update(data).eq('id', id).select();
      }
      if (rows.isEmpty) {
        return 'Perubahan ditolak database (izin akses). Pastikan akun staff terdaftar di tabel users.';
      }
    } catch (e) {
      return _flashError(e);
    }

    await reloadFlashSales();
    return null;
  }

  /// Ends a flash sale immediately (row kept for history).
  Future<String?> endFlashSale(String id) async {
    if (supabase.auth.currentUser == null) {
      return 'Sesi Supabase tidak ditemukan. Login ulang dengan akun staff.';
    }
    try {
      final rows = await supabase
          .from('flash_sales')
          .update({'is_active': false})
          .eq('id', id)
          .select();
      if (rows.isEmpty) return 'Perubahan ditolak database (izin akses).';
    } catch (e) {
      return _flashError(e);
    }
    await reloadFlashSales();
    return null;
  }

  /// Permanently deletes a flash sale row.
  Future<String?> deleteFlashSale(String id) async {
    if (supabase.auth.currentUser == null) {
      return 'Sesi Supabase tidak ditemukan. Login ulang dengan akun staff.';
    }
    try {
      final rows = await supabase.from('flash_sales').delete().eq('id', id).select();
      if (rows.isEmpty) return 'Perubahan ditolak database (izin akses).';
    } catch (e) {
      return _flashError(e);
    }
    await reloadFlashSales();
    return null;
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
