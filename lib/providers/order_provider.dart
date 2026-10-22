import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderProvider extends ChangeNotifier {
  String? _userId;
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  String? get userId => _userId;
  bool get isLoading => _isLoading;

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
          _orders = list.map((item) => OrderModel.fromMap(item as Map<String, dynamic>)).toList();
          notifyListeners();
        } catch (e) {
          debugPrint('Error decoding cached orders: $e');
        }
      } else {
        _orders = [];
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
            _orders = res.map((data) => OrderModel.fromMap(data as Map<String, dynamic>)).toList();
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

      // Apply admin status overrides
      try {
        final prefs = await SharedPreferences.getInstance();
        final overridesJson = prefs.getString('admin_order_status_overrides');
        if (overridesJson != null && overridesJson.isNotEmpty) {
          final Map<String, dynamic> overrides = jsonDecode(overridesJson);
          for (int i = 0; i < _orders.length; i++) {
            final oid = _orders[i].id;
            if (overrides.containsKey(oid)) {
              final statusStr = overrides[oid].toString();
              OrderStatus? newStatus;
              for (final s in OrderStatus.values) {
                if (s.name == statusStr) {
                  newStatus = s;
                  break;
                }
              }
              if (newStatus != null && _orders[i].status != newStatus) {
                final o = _orders[i];
                _orders[i] = OrderModel(
                  id: o.id,
                  items: o.items,
                  totalPrice: o.totalPrice,
                  status: newStatus,
                  orderDate: o.orderDate,
                  shippingAddress: o.shippingAddress,
                  paymentMethod: o.paymentMethod,
                  trackingNumber: o.trackingNumber,
                  courier: o.courier,
                  serialNumber: o.serialNumber,
                  warrantyDurationMonths: o.warrantyDurationMonths,
                  rating: o.rating,
                  reviewComment: o.reviewComment,
                  ratedAt: o.ratedAt,
                  reviewMediaUrls: o.reviewMediaUrls,
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error applying order status overrides: $e');
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
      return _orders.firstWhere((o) => o.serialNumber.toLowerCase() == serial.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// Give or update rating (validates 7-day policy)
  bool updateOrderRating(String orderId, double newRating, String comment, {List<String>? mediaUrls}) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return false;

    final order = _orders[index];
    if (order.hasRating && !order.canEditRating) {
      return false;
    }

    order.rating = newRating;
    order.reviewComment = comment;
    order.ratedAt ??= DateTime.now();
    if (mediaUrls != null) {
      order.reviewMediaUrls = mediaUrls;
    }

    _saveOrdersToCache();
    notifyListeners();

    if (_userId != null) {
      try {
        final updateData = <String, dynamic>{
          'rating': newRating,
          'review_comment': comment,
          'rated_at': DateTime.now().toIso8601String(),
        };
        if (mediaUrls != null) {
          updateData['review_media_urls'] = mediaUrls;
        }
        supabase.from('orders').update(updateData).eq('id', orderId).then((_) {}).catchError((e) {
          debugPrint('Error updating order rating in DB: $e');
        });
      } catch (e) {
        debugPrint('Error updating order rating in DB: $e');
      }
    }

    return true;
  }

  /// Admin/Cashier can update order status
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    // Update in-memory
    final index = _orders.indexWhere((o) => o.id == orderId);
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
    }

    // Persist override in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> overrides = {};
      final existingJson = prefs.getString('admin_order_status_overrides');
      if (existingJson != null && existingJson.isNotEmpty) {
        overrides = Map<String, dynamic>.from(jsonDecode(existingJson));
      }
      overrides[orderId] = newStatus.name;
      await prefs.setString('admin_order_status_overrides', jsonEncode(overrides));
    } catch (e) {
      debugPrint('Error saving order status override: $e');
    }

    // Try Supabase update
    try {
      await supabase.from('orders').update({'status': newStatus.name}).eq('id', orderId);
    } catch (e) {
      debugPrint('Supabase order status update notice: $e');
    }

    await _saveOrdersToCache();
    return true;
  }

  Future<void> addOrder(OrderModel newOrder) async {
    _orders.insert(0, newOrder);
    notifyListeners();
    await _saveOrdersToCache();

    if (_userId != null) {
      // 1. Try full insert with extended schema
      final fullData = {
        'id': newOrder.id,
        'user_id': _userId!,
        'total_price': newOrder.totalPrice,
        'status': newOrder.status.name,
        'order_date': newOrder.orderDate.toIso8601String(),
        'shipping_address': newOrder.shippingAddress,
        'payment_method': newOrder.paymentMethod,
        'tracking_number': newOrder.trackingNumber,
        'courier': newOrder.courier,
        'serial_number': newOrder.serialNumber,
        'warranty_months': newOrder.warrantyDurationMonths,
        'items_summary': jsonEncode(newOrder.items.map((it) => it.toMap()).toList()),
      };

      try {
        await supabase.from('orders').insert(fullData);
      } catch (e) {
        debugPrint('Full order insert notice, trying standard columns: $e');
        try {
          // Fallback to standard columns defined in base schema
          await supabase.from('orders').insert({
            'id': newOrder.id,
            'user_id': _userId!,
            'total_price': newOrder.totalPrice,
            'status': newOrder.status.name,
            'order_date': newOrder.orderDate.toIso8601String(),
            'shipping_address': newOrder.shippingAddress,
            'payment_method': newOrder.paymentMethod,
          });
        } catch (e2) {
          debugPrint('Standard order insert notice: $e2');
        }
      }

      // 2. Also try inserting into order_items table (only for catalog products with valid FK)
      for (final item in newOrder.items) {
        if (item.product.id.startsWith('build-')) continue;
        try {
          await supabase.from('order_items').insert({
            'order_id': newOrder.id,
            'product_id': item.product.id,
            'quantity': item.quantity,
            'unit_price': item.product.price,
          });
        } catch (e) {
          debugPrint('Order item insert notice: $e');
        }
      }
    }
  }
}
