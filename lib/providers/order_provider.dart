import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';
import 'package:doctor_computer/data/mock/mock_products.dart';

class OrderProvider extends ChangeNotifier {
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
    return true;
  }

  void addOrder(OrderModel newOrder) {
    _orders.insert(0, newOrder);
    notifyListeners();
  }
}
