import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/models/category_model.dart';
import 'package:doctor_computer/data/mock/mock_categories.dart';
import 'package:doctor_computer/data/mock/mock_products.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  String? _selectedCategoryId;
  String _searchQuery = '';
  String _sortBy = 'popular';
  RangeValues _priceRange = const RangeValues(0, 50000000);
  final List<String> _selectedBrands = [];

  List<CategoryModel> _categories = [];
  List<ProductModel> _allProducts = [];

  bool _isLoading = false;

  ProductProvider() {
    _loadData();
  }

  List<CategoryModel> get categories => _categories.isNotEmpty ? _categories : mockCategories;
  List<ProductModel> get allProducts => _allProducts.isNotEmpty ? _allProducts : mockProducts;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  bool get isLoading => _isLoading;

  List<ProductModel> get filteredProducts {
    List<ProductModel> result = List<ProductModel>.from(allProducts);

    if (_selectedCategoryId != null) {
      result = result.where((p) {
        // Match both exact category_id or name lowercase
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

      if (prodsRes.isNotEmpty) {
        _allProducts = prodsRes.map((p) {
          final rawImages = p['image_url'];
          List<String> images = [];
          if (rawImages is List) {
            images = rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
          } else if (rawImages is String && rawImages.isNotEmpty) {
            images = [rawImages];
          }

          if (images.isEmpty) {
            images = [_getPlaceholderImage(p['name']?.toString() ?? '', p['brand']?.toString() ?? '')];
          }

          Map<String, String> specsMap = {};
          if (p['specs'] is Map) {
            specsMap = (p['specs'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
          }

          final price = (p['price'] as num?)?.toDouble() ?? 0.0;
          final origPrice = (p['original_price'] as num?)?.toDouble();

          return ProductModel(
            id: p['id']?.toString() ?? '',
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
            isNew: p['is_new'] as bool? ?? true,
            isOnSale: p['is_on_sale'] as bool? ?? (origPrice != null && origPrice > price),
          );
        }).toList();
      } else {
        _allProducts = List.from(mockProducts);
      }
    } catch (e) {
      debugPrint('Error loading Supabase products: $e');
      if (_categories.isEmpty) _categories = List.from(mockCategories);
      if (_allProducts.isEmpty) _allProducts = List.from(mockProducts);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _getPlaceholderImage(String name, String brand) {
    final lower = name.toLowerCase();
    if (lower.contains('rtx') || lower.contains('gpu') || lower.contains('radeon')) {
      return 'https://images.unsplash.com/photo-1591488320449-011701bb6704?w=500&q=80';
    } else if (lower.contains('core') || lower.contains('ryzen') || lower.contains('cpu')) {
      return 'https://images.unsplash.com/photo-1555680202-c86f0e12f086?w=500&q=80';
    } else if (lower.contains('ram') || lower.contains('ddr')) {
      return 'https://images.unsplash.com/photo-1562976540-1502c2145186?w=500&q=80';
    } else if (lower.contains('laptop') || lower.contains('vivobook') || lower.contains('tuf')) {
      return 'https://images.unsplash.com/photo-1603302576837-37561b2e2302?w=500&q=80';
    } else if (lower.contains('motherboard') || lower.contains('b660') || lower.contains('z790')) {
      return 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=500&q=80';
    } else if (lower.contains('ssd') || lower.contains('storage') || lower.contains('samsung')) {
      return 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=500&q=80';
    } else if (lower.contains('mouse') || lower.contains('g502')) {
      return 'https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=500&q=80';
    }
    return 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=500&q=80';
  }

  IconData _mapIcon(String iconName) {
    final lower = iconName.toLowerCase();
    if (lower.contains('laptop') || lower.contains('💻')) return Icons.laptop_mac;
    if (lower.contains('desktop') || lower.contains('🖥️') || lower.contains('periph')) return Icons.desktop_windows;
    if (lower.contains('monitor')) return Icons.monitor;
    if (lower.contains('keyboard')) return Icons.keyboard;
    if (lower.contains('mouse')) return Icons.mouse;
    if (lower.contains('headset') || lower.contains('audio')) return Icons.headset;
    if (lower.contains('storage') || lower.contains('ssd') || lower.contains('💿')) return Icons.storage;
    if (lower.contains('router') || lower.contains('network')) return Icons.router;
    if (lower.contains('cpu') || lower.contains('⚡')) return Icons.memory;
    if (lower.contains('gpu') || lower.contains('🎮')) return Icons.videogame_asset;
    if (lower.contains('motherboard') || lower.contains('🧩')) return Icons.developer_board;
    if (lower.contains('ram') || lower.contains('💾')) return Icons.sd_card;
    if (lower.contains('case') || lower.contains('📦')) return Icons.inventory_2;
    if (lower.contains('cooler') || lower.contains('❄️')) return Icons.ac_unit;
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