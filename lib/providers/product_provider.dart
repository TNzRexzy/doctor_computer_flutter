import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/models/category_model.dart';
import 'package:doctor_computer/data/mock/mock_products.dart';
import 'package:doctor_computer/data/mock/mock_categories.dart';

class ProductProvider extends ChangeNotifier {
  final List<ProductModel> _allProducts;
  final List<CategoryModel> _categories;

  String? _selectedCategoryId;
  String _searchQuery = '';
  String _sortBy = 'popular';
  RangeValues _priceRange = const RangeValues(0, 50000000);
  List<String> _selectedBrands = [];

  ProductProvider()
      : _allProducts = mockProducts,
        _categories = mockCategories;

  List<CategoryModel> get categories => _categories;
  String get sortBy => _sortBy;
  String get searchQuery => _searchQuery;

  List<ProductModel> get filteredProducts {
    List<ProductModel> result = _allProducts;

    if (_selectedCategoryId != null) {
      result = result.where((p) => p.categoryId == _selectedCategoryId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((p) => 
        p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
        p.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    result = result.where((p) => p.price >= _priceRange.start && p.price <= _priceRange.end).toList();

    if (_selectedBrands.isNotEmpty) {
      result = result.where((p) => _selectedBrands.contains(p.brand)).toList();
    }

    if (_sortBy == 'popular') {
      result.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    } else if (_sortBy == 'price_low') {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'price_high') {
      result.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortBy == 'rating') {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return result;
  }

  List<ProductModel> get flashDeals {
    return _allProducts.where((p) => p.isOnSale).take(10).toList();
  }

  List<ProductModel> get newArrivals {
    return _allProducts.where((p) => p.isNew).take(10).toList();
  }

  List<ProductModel> get bestSellers {
    var sorted = List<ProductModel>.from(_allProducts);
    sorted.sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(10).toList();
  }

  List<String> get availableBrands {
    var products = _allProducts;
    if (_selectedCategoryId != null) {
      products = products.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    return products.map((p) => p.brand).toSet().toList();
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

  ProductModel? getProductById(String id) {
    try {
      return _allProducts.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
