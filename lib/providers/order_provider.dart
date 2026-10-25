import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';
import 'package:doctor_computer/data/mock/mock_products.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderProvider extends ChangeNotifier {
  String? _userId;
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;

  String? get userId => _userId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  OrderProvider() {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId != null) {
      setUserId(currentUserId);
    } else {
      _loadOrders();
    }
  }

  void setUserId(String? id) {
    if (_userId == id && _orders.isNotEmpty) return;
    _userId = id;
    _loadOrders();
  }

  /// Initial placeholder orders for guest preview only
  List<OrderModel> _getDefaultMockOrders() {
    return [
      OrderModel(
        id: 'ORD-1001',
        items: [CartItemModel(product: mockProducts[0], quantity: 1)],
        totalPrice: 15500000,
        status: OrderStatus.processing,
        orderDate: DateTime.now().subtract(const Duration(hours: 4)),
        shippingAddress: 'Jl. Merdeka No 1, Jakarta Pusat',
        paymentMethod: 'Transfer Bank BCA',
        trackingNumber: 'JNE-DC98124982',
        courier: 'JNE Reguler',
        serialNumber: 'SN-TUF-2026-98124',
        warrantyDurationMonths: 24,
      ),
      OrderModel(
        id: 'ORD-1002',
        items: [CartItemModel(product: mockProducts[1], quantity: 1)],
        totalPrice: 9499000,
        status: OrderStatus.shipped,
        orderDate: DateTime.now().subtract(const Duration(days: 2)),
        shippingAddress: 'Jl. Sudirman No 10, Bandung',
        paymentMethod: 'GoPay',
        trackingNumber: 'SICEPAT-DC458291',
        courier: 'SiCepat BEST',
        serialNumber: 'SN-LNV-2026-45829',
        warrantyDurationMonths: 12,
      ),
      OrderModel(
        id: 'ORD-1003',
        items: [CartItemModel(product: mockProducts[2], quantity: 1)],
        totalPrice: 18999000,
        status: OrderStatus.delivered,
        orderDate: DateTime.now().subtract(const Duration(days: 8)),
        shippingAddress: 'Jl. Diponegoro No 45, Surabaya',
        paymentMethod: 'Transfer Bank Mandiri',
        trackingNumber: 'JNT-DC7718293',
        courier: 'J&T Express',
        serialNumber: 'SN-APP-2026-77182',
        warrantyDurationMonths: 12,
      ),
      OrderModel(
        id: 'ORD-1004',
        items: [CartItemModel(product: mockProducts[3], quantity: 1)],
        totalPrice: 13499000,
        status: OrderStatus.delivered,
        orderDate: DateTime.now().subtract(const Duration(days: 15)),
        shippingAddress: 'Jl. Gatot Subroto No 88, Semarang',
        paymentMethod: 'OVO',
        trackingNumber: 'JNE-DC5529184',
        courier: 'JNE YES',
        serialNumber: 'SN-MSI-2026-55291',
        warrantyDurationMonths: 24,
        rating: 5.0,
        reviewComment: 'Performa sangat dingin dan build quality solid! Pelayanan Doctor Computer luar biasa ramah.',
        ratedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      OrderModel(
        id: 'ORD-1005',
        items: [CartItemModel(product: mockProducts[4], quantity: 2)],
        totalPrice: 4200000,
        status: OrderStatus.delivered,
        orderDate: DateTime.now().subtract(const Duration(days: 45)),
        shippingAddress: 'Jl. Malioboro No 20, Yogyakarta',
        paymentMethod: 'Dana',
        trackingNumber: 'POS-DC1182743',
        courier: 'Pos Indonesia Kilat',
        serialNumber: 'SN-SAM-2026-11827',
        warrantyDurationMonths: 36,
        rating: 4.0,
        reviewComment: 'Kecepatan baca tulis sesuai spesifikasi, packaging bubble wrap tebal.',
        ratedAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
    ];
  }

  List<OrderModel> _orders = [];

  List<OrderModel> get orders => List.unmodifiable(_orders);

  String get _cacheKey => 'cached_orders_${_userId ?? "guest"}';

  Future<void> _saveOrdersToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderMaps = _orders.map((o) => o.toMap()).toList();
      await prefs.setString(_cacheKey, jsonEncode(orderMaps));
    } catch (e) {
      debugPrint('Error saving orders to local cache: $e');
    }
  }

  Future<void> reloadOrders() async {
    await _loadOrders();
  }

  Future<void> _loadOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. First, load from SharedPreferences (instant, offline-first)
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final List list = jsonDecode(cachedJson) as List;
          _orders = list
              .map((item) => OrderModel.fromMap(item as Map<String, dynamic>))
              .toList();
          notifyListeners();
        } catch (e) {
          debugPrint('Error decoding cached orders: $e');
        }
      } else if (_userId == null) {
        // Only use mock orders for fresh guest sessions
        _orders = _getDefaultMockOrders();
        notifyListeners();
      }

      // 2. Second, fetch from Supabase if user is logged in
      if (_userId != null) {
        try {
          final List res = await supabase
              .from('orders')
              .select()
              .eq('user_id', _userId!)
              .order('order_date', ascending: false);

          if (res.isNotEmpty) {
            _orders = res
                .map((data) => OrderModel.fromMap(data as Map<String, dynamic>))
                .toList();
            await _saveOrdersToCache();
            notifyListeners();
          } else if (_orders.isEmpty) {
            // New registered user with 0 orders in database
            _orders = [];
            await _saveOrdersToCache();
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Supabase orders fetch notice: $e');
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  OrderModel? getOrderById(String id) {
    try {
      return _orders.firstWhere((o) => o.id.toLowerCase() == id.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  OrderModel? getOrderBySerial(String serial) {
    try {
      return _orders.firstWhere(
        (o) => o.serialNumber.toLowerCase() == serial.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Give or update rating (validates 7-day policy)
  Future<bool> updateOrderRating(
    String orderId,
    double newRating,
    String comment, {
    List<String>? mediaUrls,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return false;

    final order = _orders[index];
    if (order.hasRating && !order.canEditRating) {
      return false;
    }

    try {
      await supabase.rpc(
        'rate_order',
        params: {
          'p_order_id': orderId,
          'p_rating': newRating,
          'p_comment': comment,
          'p_media_urls': mediaUrls ?? <String>[],
        },
      );
      order.rating = newRating;
      order.reviewComment = comment;
      order.ratedAt = DateTime.now();
      order.reviewMediaUrls = mediaUrls ?? [];
      await _saveOrdersToCache();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Rating gagal disimpan: $e';
      debugPrint('Error saving order rating: $e');
      return false;
    }
  }

  /// Admin/Cashier can update order status
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    try {
      await supabase.rpc(
        'update_order_status',
        params: {'p_order_id': orderId, 'p_status': newStatus.name},
      );
      if (index >= 0) {
        final order = _orders[index];
        _orders[index] = OrderModel(
          id: order.id,
          items: order.items,
          totalPrice: order.totalPrice,
          status: newStatus,
          orderDate: order.orderDate,
          shippingAddress: order.shippingAddress,
          paymentMethod: order.paymentMethod,
          trackingNumber: order.trackingNumber,
          courier: order.courier,
          serialNumber: order.serialNumber,
          warrantyDurationMonths: order.warrantyDurationMonths,
          rating: order.rating,
          reviewComment: order.reviewComment,
          ratedAt: order.ratedAt,
          reviewMediaUrls: order.reviewMediaUrls,
        );
        notifyListeners();
        await _saveOrdersToCache();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Status pesanan gagal diperbarui: $e';
      debugPrint('Supabase order status update failed: $e');
      return false;
    }
  }

  /// Admin/Cashier can input or update the courier and tracking number (resi)
  Future<bool> updateOrderTracking(
    String orderId, {
    required String courier,
    required String trackingNumber,
  }) async {
    _errorMessage = null;
    try {
      await supabase.rpc(
        'update_order_tracking',
        params: {
          'p_order_id': orderId,
          'p_courier': courier,
          'p_tracking_number': trackingNumber,
        },
      );
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        final order = _orders[index];
        _orders[index] = OrderModel(
          id: order.id,
          items: order.items,
          totalPrice: order.totalPrice,
          status: order.status,
          orderDate: order.orderDate,
          shippingAddress: order.shippingAddress,
          paymentMethod: order.paymentMethod,
          trackingNumber: trackingNumber.trim(),
          courier: courier.trim().isEmpty ? order.courier : courier.trim(),
          serialNumber: order.serialNumber,
          warrantyDurationMonths: order.warrantyDurationMonths,
          channel: order.channel,
          cashierId: order.cashierId,
          rating: order.rating,
          reviewComment: order.reviewComment,
          ratedAt: order.ratedAt,
          reviewMediaUrls: order.reviewMediaUrls,
        );
        notifyListeners();
        await _saveOrdersToCache();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Nomor resi gagal disimpan: $e';
      debugPrint('Supabase order tracking update failed: $e');
      return false;
    }
  }

  Future<OrderModel?> addOrder(
    OrderModel newOrder, {
    required String shippingMethod,
  }) async {
    if (_userId == null) {
      _errorMessage = 'Silakan login sebelum membuat pesanan.';
      return null;
    }
    _errorMessage = null;
    try {
      final response = await supabase.rpc(
        'create_customer_order',
        params: {
          'p_items': newOrder.items
              .map(
                (item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                },
              )
              .toList(),
          'p_shipping_address': newOrder.shippingAddress,
          'p_payment_method': newOrder.paymentMethod,
          'p_shipping_method': shippingMethod,
        },
      );
      if (response is! Map) {
        throw const FormatException(
          'Respons create_customer_order tidak valid.',
        );
      }
      final savedOrder = OrderModel.fromMap(
        Map<String, dynamic>.from(response),
      );
      if (savedOrder.id.isEmpty) {
        throw const FormatException(
          'Respons create_customer_order tidak memiliki ID.',
        );
      }
      _orders.insert(0, savedOrder);
      await _saveOrdersToCache();
      notifyListeners();
      return savedOrder;
    } catch (e) {
      _errorMessage = 'Pesanan gagal disimpan: $e';
      debugPrint('create_customer_order failed: $e');
      return null;
    }
  }
}
