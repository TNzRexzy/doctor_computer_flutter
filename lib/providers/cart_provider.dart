import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/mock/mock_products.dart';
import 'package:doctor_computer/core/constants/app_images.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  String? _userId;
  String? _appliedVoucherCode;
  String? _voucherMessage;
  double _voucherDiscount = 0;
  double _voucherSubtotal = 0;
  bool _isApplyingVoucher = false;
  List<Map<String, dynamic>> _availableVouchers = [];
  bool _isLoadingAvailableVouchers = false;
  String? _availableVoucherError;
  double? _availableVoucherSubtotal;
  int _voucherListRequest = 0;

  List<CartItemModel> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice => _items.fold(0, (sum, item) => sum + item.subtotal);
  String? get appliedVoucherCode => _appliedVoucherCode;
  String? get voucherMessage => _voucherMessage;
  bool get isApplyingVoucher => _isApplyingVoucher;
  List<Map<String, dynamic>> get availableVouchers =>
      List.unmodifiable(_availableVouchers);
  List<Map<String, dynamic>> get eligibleVouchers => List.unmodifiable(
    _availableVouchers.where((voucher) {
      final eligibleAmount = _voucherEligibleAmount(voucher);
      final minimum = (voucher['min_purchase'] as num?)?.toDouble() ?? 0;
      return eligibleAmount > 0 && eligibleAmount >= minimum;
    }).toList(),
  );
  bool get isLoadingAvailableVouchers => _isLoadingAvailableVouchers;
  String? get availableVoucherError => _availableVoucherError;
  double get voucherDiscount =>
      _appliedVoucherCode != null && _voucherSubtotal == totalPrice
      ? _voucherDiscount
      : 0;
  String? get appliedVoucherScope {
    final code = _appliedVoucherCode;
    if (code == null) return null;
    for (final voucher in _availableVouchers) {
      if (voucher['code']?.toString().toUpperCase() == code) {
        return voucher['discount_scope']?.toString() ?? 'all';
      }
    }
    return null;
  }

  double voucherDiscountForShipping(double shippingAmount) {
    if (appliedVoucherScope != 'shipping' || _voucherSubtotal != totalPrice) {
      return voucherDiscount;
    }
    final voucher = _availableVouchers.firstWhere(
      (item) => item['code']?.toString().toUpperCase() == _appliedVoucherCode,
    );
    final type = voucher['discount_type']?.toString() ?? 'fixed';
    final value = (voucher['discount_value'] as num?)?.toDouble() ?? 0;
    final maxDiscount = (voucher['max_discount'] as num?)?.toDouble();
    var discount = type == 'percent' ? shippingAmount * value / 100 : value;
    if (maxDiscount != null) {
      discount = discount.clamp(0, maxDiscount).toDouble();
    }
    return discount.clamp(0, shippingAmount).toDouble();
  }

  String? get userId => _userId;
  set userId(String? id) {
    if (_userId == id) return;
    _userId = id;
    _items.clear();
    clearVoucher(notify: false);
    _voucherListRequest++;
    _isLoadingAvailableVouchers = false;
    _availableVoucherSubtotal = null;
    _availableVouchers = [];
    _availableVoucherError = null;
    _notifyCartChanged();
    _loadCartFromCache().then((_) => _syncCartFromDb());
  }

  final supabase = Supabase.instance.client;

  CartProvider() {
    // Saat flash sale berakhir, harga di keranjang ikut kembali normal.
    ProductProvider.flashSaleExpired.addListener(refreshPrices);
  }

  @override
  void dispose() {
    ProductProvider.flashSaleExpired.removeListener(refreshPrices);
    super.dispose();
  }

  /// Mengambil ulang harga setiap produk di keranjang dari database
  /// (jumlah tetap). Produk rakitan PC (`build-...`) dilewati.
  Future<void> refreshPrices() async {
    if (_items.isEmpty) return;
    try {
      var changed = false;
      final ids = _items
          .map((i) => i.product.id)
          .where((id) => !id.startsWith('build-'))
          .toList();
      for (final id in ids) {
        final fresh = await _fetchProductAsync(id);
        if (fresh == null) continue;
        final index = _items.indexWhere((i) => i.product.id == id);
        if (index < 0) continue;
        final old = _items[index].product;
        if (fresh.price != old.price ||
            fresh.originalPrice != old.originalPrice ||
            fresh.isOnSale != old.isOnSale) {
          _items[index] = CartItemModel(
            product: fresh,
            quantity: _items[index].quantity,
          );
          changed = true;
        }
      }
      if (changed) _notifyCartChanged();
    } catch (e) {
      debugPrint('Error refreshing cart prices: $e');
    }
  }

  void setUserId(String? id) {
    if (_userId == id) return;
    _userId = id;
    _items.clear();
    clearVoucher(notify: false);
    _voucherListRequest++;
    _isLoadingAvailableVouchers = false;
    _availableVoucherSubtotal = null;
    _availableVouchers = [];
    _availableVoucherError = null;
    _notifyCartChanged();
    _loadCartFromCache().then((_) => _syncCartFromDb());
  }

  Future<void> loadAvailableVouchers() async {
    final subtotal = totalPrice;
    final requestId = ++_voucherListRequest;
    _isLoadingAvailableVouchers = true;
    _availableVoucherError = null;
    notifyListeners();

    try {
      final response = await supabase.rpc(
        'list_available_vouchers',
        params: {'p_subtotal': subtotal},
      );
      if (response is! List) {
        throw const FormatException(
          'Respons daftar voucher yang tersedia tidak valid.',
        );
      }
      final vouchers = response
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (requestId != _voucherListRequest) return;
      if (subtotal != totalPrice) {
        _availableVoucherSubtotal = null;
        _availableVouchers = [];
      } else {
        _availableVoucherSubtotal = subtotal;
        _availableVouchers = vouchers;
      }
    } catch (error) {
      if (requestId != _voucherListRequest) return;
      _availableVouchers = [];
      _availableVoucherSubtotal = subtotal;
      _availableVoucherError = 'Voucher gagal dimuat: $error';
      debugPrint('Error loading available vouchers: $error');
    } finally {
      if (requestId == _voucherListRequest) {
        _isLoadingAvailableVouchers = false;
        notifyListeners();
        if (subtotal != totalPrice) {
          unawaited(loadAvailableVouchers());
        }
      }
    }
  }

  Future<void> applyVoucher(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      _appliedVoucherCode = null;
      _voucherDiscount = 0;
      _voucherMessage = 'Masukkan kode voucher terlebih dahulu.';
      notifyListeners();
      return;
    }

    final subtotal = totalPrice;
    final voucher = _availableVouchers.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['code']?.toString().toUpperCase() == normalizedCode,
      orElse: () => null,
    );
    if (voucher == null) {
      _appliedVoucherCode = null;
      _voucherDiscount = 0;
      _voucherMessage = 'Voucher tidak tersedia di keranjang ini.';
      notifyListeners();
      return;
    }
    final eligibleAmount = _voucherEligibleAmount(voucher);
    if (eligibleAmount <= 0) {
      _appliedVoucherCode = null;
      _voucherDiscount = 0;
      _voucherMessage = 'Voucher ini tidak sesuai dengan isi keranjang.';
      notifyListeners();
      return;
    }
    _isApplyingVoucher = true;
    _voucherMessage = null;
    notifyListeners();

    try {
      final response = await supabase.rpc(
        'validate_voucher',
        params: {'p_code': normalizedCode, 'p_subtotal': eligibleAmount},
      );
      if (response is! Map) {
        throw const FormatException('Respons validasi voucher tidak valid.');
      }
      final result = Map<String, dynamic>.from(response);
      if (subtotal != totalPrice) {
        _appliedVoucherCode = null;
        _voucherDiscount = 0;
        _voucherMessage =
            'Isi keranjang berubah. Silakan gunakan voucher lagi.';
      } else if (result['success'] == true) {
        _appliedVoucherCode = normalizedCode;
        _voucherDiscount = (result['discount_amount'] as num?)?.toDouble() ?? 0;
        _voucherSubtotal = subtotal;
        _voucherMessage =
            result['message']?.toString() ?? 'Voucher berhasil digunakan.';
      } else {
        _appliedVoucherCode = null;
        _voucherDiscount = 0;
        _voucherMessage =
            result['message']?.toString() ?? 'Voucher tidak dapat digunakan.';
      }
    } catch (error) {
      _appliedVoucherCode = null;
      _voucherDiscount = 0;
      _voucherMessage = 'Voucher gagal diperiksa: $error';
      debugPrint('Error validating voucher: $error');
    } finally {
      _isApplyingVoucher = false;
      notifyListeners();
    }
  }

  double _voucherEligibleAmount(Map<String, dynamic> voucher) {
    final scope = voucher['discount_scope']?.toString() ?? 'all';
    switch (scope) {
      case 'product':
        return _items
            .where((item) => item.product.categoryId != 'service')
            .fold(0.0, (sum, item) => sum + item.subtotal);
      case 'build_service':
        return _items
            .where((item) => item.product.categoryId == 'service')
            .fold(0.0, (sum, item) => sum + item.subtotal);
      case 'shipping':
        return 15000;
      case 'all':
        return totalPrice;
      default:
        return 0;
    }
  }

  static bool _isBuildService(String productId) =>
      productId == 'build-service-standard' ||
      productId == 'build-service-premium';

  void clearVoucher({bool notify = true}) {
    _appliedVoucherCode = null;
    _voucherMessage = null;
    _voucherDiscount = 0;
    _voucherSubtotal = 0;
    if (notify) notifyListeners();
  }

  void _notifyCartChanged() {
    if (_appliedVoucherCode != null && _voucherSubtotal != totalPrice) {
      _appliedVoucherCode = null;
      _voucherDiscount = 0;
      _voucherMessage = 'Isi keranjang berubah. Silakan gunakan voucher lagi.';
    }
    if (_availableVoucherSubtotal != totalPrice &&
        !_isLoadingAvailableVouchers) {
      unawaited(loadAvailableVouchers());
    }
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

      final localBuildServices = _items
          .where((item) => _isBuildService(item.product.id))
          .toList();
      _items
        ..clear()
        ..addAll(localBuildServices);
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
      _notifyCartChanged();
    } catch (e) {
      debugPrint('Error loading cart from db: $e');
    }
  }

  Future<ProductModel?> _fetchProductAsync(String productId) async {
    if (productId == 'build-service-standard' ||
        productId == 'build-service-premium') {
      final isPremium = productId == 'build-service-premium';
      return ProductModel(
        id: productId,
        name: isPremium ? 'Jasa Rakit PC Premium' : 'Jasa Rakit PC Standard',
        description: 'Biaya jasa perakitan PC',
        descriptionId: 'Biaya jasa perakitan PC',
        price: isPremium ? 500000 : 250000,
        categoryId: 'service',
        brand: 'Doctor Computer',
        images: const [],
        specs: const {},
        rating: 5,
        reviewCount: 0,
        stock: 999,
        isNew: false,
        isOnSale: false,
      );
    }
    try {
      final data = await supabase
          .from('products')
          .select()
          .eq('id', productId)
          .maybeSingle();

      if (data != null) {
        final rawImages = data['image_url'];
        final List<String> images = AppImages.resolveProductImages(
          rawImages,
          data['id']?.toString() ?? productId,
          productName: data['name']?.toString() ?? '',
          categoryId: data['category_id']?.toString(),
          brand: data['brand']?.toString(),
        );

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
      debugPrint('Error fetching product from Supabase: $e');
    }

    // Fallback to mock product
    try {
      return mockProducts.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// Returns false (and does not add anything) when the product is out of stock
  /// or the requested quantity would exceed the available stock.
  Future<bool> addToCart(ProductModel product, {int quantity = 1}) async {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );
    final currentQty = existingIndex >= 0 ? _items[existingIndex].quantity : 0;
    if (product.stock <= 0 || currentQty + quantity > product.stock) {
      return false;
    }

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItemModel(product: product, quantity: quantity));
    }
    _notifyCartChanged();
    _saveCartToCache();

    if (_userId != null && !_isBuildService(product.id)) {
      try {
        await supabase.from('cart_items').upsert({
          'user_id': _userId!,
          'product_id': product.id,
          'quantity': existingIndex >= 0
              ? _items[existingIndex].quantity
              : quantity,
        }, onConflict: 'user_id,product_id');
      } catch (e) {
        debugPrint('Error persisting cart item to db: $e');
      }
    }
    return true;
  }

  Future<void> removeFromCart(String productId) async {
    _items.removeWhere((item) => item.product.id == productId);
    _notifyCartChanged();
    _saveCartToCache();

    if (_userId != null && !_isBuildService(productId)) {
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
      // Do not allow raising the quantity above the available stock.
      if (quantity > _items[index].quantity &&
          quantity > _items[index].product.stock) {
        return;
      }
      _items[index].quantity = quantity;
      _notifyCartChanged();
      _saveCartToCache();
    }

    if (_userId != null && !_isBuildService(productId)) {
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
    clearVoucher(notify: false);
    notifyListeners();
    _saveCartToCache();

    if (_userId != null) {
      try {
        await supabase.from('cart_items').delete().eq('user_id', _userId!);
      } catch (e) {
        debugPrint('Error clearing cart in db: $e');
      }
    }
  }

  bool isInCart(String productId) {
    return _items.any((item) => item.product.id == productId);
  }

  Future<void> _loadCartFromCache() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'user_cart_$_userId';
      final cached = prefs.getString(key);
      if (cached != null && cached.isNotEmpty) {
        final List list = jsonDecode(cached);
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final product = await _fetchProductAsync(map['product_id'] ?? '');
          if (product != null) {
            _items.add(
              CartItemModel(
                product: product,
                quantity: (map['quantity'] as num? ?? 1).toInt(),
              ),
            );
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart from cache: $e');
    }
  }

  Future<void> _saveCartToCache() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'user_cart_$_userId';
      final data = _items
          .map((i) => {'product_id': i.product.id, 'quantity': i.quantity})
          .toList();
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving cart to cache: $e');
    }
  }
}
