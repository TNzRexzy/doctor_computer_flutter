import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';
import 'package:doctor_computer/data/mock/mock_products.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderProvider extends ChangeNotifier {
  String? _userId;
  final supabase = Supabase.instance.client;

  OrderProvider() {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId != null) {
      setUserId(currentUserId);
    }
  }

  void setUserId(String? id) {
    _userId = id;
    if (id != null) _loadOrdersFromDb();
    notifyListeners();
  }

  Future<void> _loadOrdersFromDb() async {
    if (_userId == null) return;
    try {
      final List res = await supabase
          .from('orders')
          .select()
          .eq('user_id', _userId!)
          .order('order_date', ascending: false);
      
      if (res.isNotEmpty) {
        // Clear mock orders and load from DB
        _orders.clear();
        for (var data in res) {
          _orders.add(_mapOrder(data));
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading orders from DB: $e');
      // Keep mock data as fallback
    }
  }

  OrderModel _mapOrder(Map<String, dynamic> data) {
    return OrderModel(
      id: data['id']?.toString() ?? '',
      items: [], // Items loaded separately or stored as JSON
      totalPrice: (data['total_price'] as num?)?.toDouble() ?? 0,
      status: _parseOrderStatus(data['status']),
      orderDate: DateTime.tryParse(data['order_date']?.toString() ?? '') ?? DateTime.now(),
      shippingAddress: data['shipping_address']?.toString() ?? '',
      paymentMethod: data['payment_method']?.toString() ?? '',
      trackingNumber: data['tracking_number']?.toString() ?? '',
      courier: data['courier']?.toString() ?? '',
      serialNumber: data['serial_number']?.toString() ?? '',
      warrantyDurationMonths: (data['warranty_months'] as num?)?.toInt() ?? 12,
      rating: (data['rating'] as num?)?.toDouble(),
      reviewComment: data['review_comment']?.toString(),
    );
  }

  OrderStatus _parseOrderStatus(dynamic status) {
    if (status is String) {
      switch (status.toLowerCase()) {
        case 'processing': return OrderStatus.processing;
        case 'shipped': return OrderStatus.shipped;
        case 'delivered': return OrderStatus.delivered;
        case 'cancelled': return OrderStatus.cancelled;
      }
    }
    return OrderStatus.processing;
  }

  final List<OrderModel> _orders = [
    OrderModel(
      id: 'ORD-1001',
      items: [
        CartItemModel(product: mockProducts[0], quantity: 1),
      ],
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
      items: [
        CartItemModel(product: mockProducts[1], quantity: 1),
      ],
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
      items: [
        CartItemModel(product: mockProducts[2], quantity: 1),
      ],
      totalPrice: 18999000,
      status: OrderStatus.delivered,
      orderDate: DateTime.now().subtract(const Duration(days: 8)),
      shippingAddress: 'Jl. Diponegoro No 45, Surabaya',
      paymentMethod: 'Transfer Bank Mandiri',
      trackingNumber: 'JNT-DC7718293',
      courier: 'J&T Express',
      serialNumber: 'SN-APP-2026-77182',
      warrantyDurationMonths: 12,
      // No rating yet -> can give rating!
    ),
    OrderModel(
      id: 'ORD-1004',
      items: [
        CartItemModel(product: mockProducts[3], quantity: 1),
      ],
      totalPrice: 13499000,
      status: OrderStatus.delivered,
      orderDate: DateTime.now().subtract(const Duration(days: 15)),
      shippingAddress: 'Jl. Gatot Subroto No 88, Semarang',
      paymentMethod: 'OVO',
      trackingNumber: 'JNE-DC5529184',
      courier: 'JNE YES (Yakin Esok Sampai)',
      serialNumber: 'SN-MSI-2026-55291',
      warrantyDurationMonths: 24,
      rating: 5.0,
      reviewComment: 'Performa sangat dingin dan build quality solid! Pelayanan Doctor Computer luar biasa ramah.',
      ratedAt: DateTime.now().subtract(const Duration(days: 2)), // 2 days ago <= 7 days -> Can edit!
    ),
    OrderModel(
      id: 'ORD-1005',
      items: [
        CartItemModel(product: mockProducts[4], quantity: 2),
      ],
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
      ratedAt: DateTime.now().subtract(const Duration(days: 12)), // 12 days ago > 7 days -> Locked!
    ),
  ];

  List<OrderModel> get orders => List.unmodifiable(_orders);

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
  bool updateOrderRating(String orderId, double newRating, String comment) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return false;

    final order = _orders[index];
    if (order.hasRating && !order.canEditRating) {
      // Cannot edit after 7 days
      return false;
    }

    order.rating = newRating;
    order.reviewComment = comment;
    // Set or keep ratedAt
    order.ratedAt ??= DateTime.now();

    notifyListeners();

    if (_userId != null) {
      try {
        supabase.from('orders').update({
          'rating': newRating,
          'review_comment': comment,
        }).eq('id', orderId).then((_) {}).catchError((e) {
          debugPrint('Error updating order rating in DB: $e');
        });
      } catch (e) {
        debugPrint('Error updating order rating in DB: $e');
      }
    }

    return true;
  }

  Future<void> addOrder(OrderModel newOrder) async {
    _orders.insert(0, newOrder);
    notifyListeners();
    
    if (_userId != null) {
      try {
        await supabase.from('orders').insert({
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
        });
      } catch (e) {
        debugPrint('Error saving order to DB: $e');
      }
    }
  }
}
