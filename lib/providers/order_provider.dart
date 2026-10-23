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
          final rows = await _fetchOrderRows();
          final localById = {for (final o in _orders) o.id: o};
          final merged = <OrderModel>[];
          final dbIds = <String>{};

          for (final raw in rows) {
            final row = Map<String, dynamic>.from(raw as Map);
            _fillItemsFromOrderItems(row);
            final dbOrder = OrderModel.fromMap(row);
            dbIds.add(dbOrder.id);
            final local = localById[dbOrder.id];
            // Orders saved with the base schema only have no tracking/items
            // columns; keep the richer local copy but trust the DB status/rating.
            if (local != null && !row.containsKey('serial_number')) {
              merged.add(OrderModel(
                id: local.id,
                items: local.items.isNotEmpty ? local.items : dbOrder.items,
                totalPrice: dbOrder.totalPrice,
                status: dbOrder.status,
                orderDate: dbOrder.orderDate,
                shippingAddress: dbOrder.shippingAddress,
                paymentMethod: dbOrder.paymentMethod,
                trackingNumber: local.trackingNumber,
                courier: local.courier,
                serialNumber: local.serialNumber,
                warrantyDurationMonths: local.warrantyDurationMonths,
                rating: dbOrder.rating ?? local.rating,
                reviewComment: dbOrder.reviewComment ?? local.reviewComment,
                ratedAt: dbOrder.ratedAt ?? local.ratedAt,
                reviewMediaUrls: local.reviewMediaUrls,
              ));
            } else {
              merged.add(dbOrder);
            }
          }

          // Orders that exist only on this device (DB insert failed earlier)
          // must not disappear: keep them and try to sync them again.
          final localOnly = _orders.where((o) => !dbIds.contains(o.id)).toList();
          merged.addAll(localOnly);
          merged.sort((a, b) => b.orderDate.compareTo(a.orderDate));
          _orders = merged;
          await _saveOrdersToCache();
          notifyListeners();

          for (final o in localOnly) {
            _syncOrderToDb(o);
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

  /// Reads the user's orders, including their order_items (with product info).
  /// Falls back to a plain select if the relationship query is not available.
  Future<List> _fetchOrderRows() async {
    try {
      return await supabase
          .from('orders')
          .select('*, order_items(quantity, unit_price, product_id, products(id, name, image_url, category_id, brand))')
          .eq('user_id', _userId!)
          .order('order_date', ascending: false);
    } catch (e) {
      debugPrint('Orders with items query notice, using plain select: $e');
      return await supabase
          .from('orders')
          .select()
          .eq('user_id', _userId!)
          .order('order_date', ascending: false);
    }
  }

  /// When an order row has no items_summary, rebuild items from order_items.
  /// unit_price is the price actually paid (so flash sale prices are kept).
  void _fillItemsFromOrderItems(Map<String, dynamic> row) {
    final summary = row['items_summary'];
    final hasSummary = summary != null &&
        !(summary is List && summary.isEmpty) &&
        !(summary is String && (summary.isEmpty || summary == '[]'));
    if (hasSummary) return;
    final rel = row['order_items'];
    if (rel is! List || rel.isEmpty) return;
    row['items_summary'] = rel.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final prod = m['products'] is Map ? Map<String, dynamic>.from(m['products'] as Map) : <String, dynamic>{};
      final img = prod['image_url'];
      return {
        'product_id': m['product_id'],
        'product_name': prod['name'] ?? 'Produk Komputer',
        'product_price': m['unit_price'],
        'product_image': img is List && img.isNotEmpty ? img.first.toString() : '',
        'category_id': prod['category_id'] ?? '',
        'brand': prod['brand'] ?? '',
        'quantity': m['quantity'],
      };
    }).toList();
  }

  /// Saves an order and its items to Supabase. Returns true if the order row
  /// reached the database.
  Future<bool> _syncOrderToDb(OrderModel newOrder) async {
    if (_userId == null) return false;
    var saved = false;

    final baseData = {
      'id': newOrder.id,
      'user_id': _userId!,
      'total_price': newOrder.totalPrice,
      'status': newOrder.status.name,
      'order_date': newOrder.orderDate.toIso8601String(),
      'shipping_address': newOrder.shippingAddress,
      'payment_method': newOrder.paymentMethod,
    };

    try {
      // 1. Full insert with extended columns
      await supabase.from('orders').insert({
        ...baseData,
        'tracking_number': newOrder.trackingNumber,
        'courier': newOrder.courier,
        'serial_number': newOrder.serialNumber,
        'warranty_months': newOrder.warrantyDurationMonths,
        'items_summary': jsonEncode(newOrder.items.map((it) => it.toMap()).toList()),
      });
      saved = true;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        saved = true; // already in the database
      } else {
        debugPrint('Full order insert notice, trying standard columns: $e');
        try {
          // 2. Fallback to the base schema columns
          await supabase.from('orders').insert(baseData);
          saved = true;
        } on PostgrestException catch (e2) {
          if (e2.code == '23505') {
            saved = true;
          } else {
            debugPrint('ORDER NOT SAVED TO DB (check RLS / user_id): $e2');
          }
        } catch (e2) {
          debugPrint('ORDER NOT SAVED TO DB: $e2');
        }
      }
    } catch (e) {
      debugPrint('Full order insert notice, trying standard columns: $e');
      try {
        // 2. Fallback to the base schema columns
        await supabase.from('orders').insert(baseData);
        saved = true;
      } catch (e2) {
        debugPrint('ORDER NOT SAVED TO DB (check RLS / user_id): $e2');
      }
    }

    if (!saved) return false;

    // 3. order_items (only catalog products with a valid FK); skip rows that exist
    try {
      final List existing = await supabase
          .from('order_items')
          .select('product_id')
          .eq('order_id', newOrder.id);
      final have = existing.map((e) => e['product_id']?.toString()).toSet();
      for (final item in newOrder.items) {
        if (item.product.id.startsWith('build-')) continue;
        if (have.contains(item.product.id)) continue;
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
    } catch (e) {
      debugPrint('Order items sync notice: $e');
    }
    return true;
  }

  /// Adds an order locally (instant) and syncs it to Supabase.
  /// Returns true if it was stored in the database.
  Future<bool> addOrder(OrderModel newOrder) async {
    _orders.insert(0, newOrder);
    notifyListeners();
    await _saveOrdersToCache();
    return _syncOrderToDb(newOrder);
  }
}
