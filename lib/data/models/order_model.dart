import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';

enum OrderStatus { processing, shipped, delivered, cancelled }

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.processing: return 'Processing';
      case OrderStatus.shipped: return 'Shipped';
      case OrderStatus.delivered: return 'Delivered';
      case OrderStatus.cancelled: return 'Cancelled';
    }
  }

  String get displayNameId {
    switch (this) {
      case OrderStatus.processing: return 'Diproses';
      case OrderStatus.shipped: return 'Dikirim';
      case OrderStatus.delivered: return 'Selesai';
      case OrderStatus.cancelled: return 'Dibatalkan';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.processing: return AppColors.warning;
      case OrderStatus.shipped: return AppColors.primary;
      case OrderStatus.delivered: return AppColors.success;
      case OrderStatus.cancelled: return AppColors.error;
    }
  }
}

/// Represents an order placed by the user with Warranty and Rating lifecycle.
class OrderModel {
  final String id;
  final List<CartItemModel> items;
  final double totalPrice;
  final OrderStatus status;
  final DateTime orderDate;
  final String shippingAddress;
  final String paymentMethod;
  final String trackingNumber;
  final String courier;
  final int warrantyDurationMonths;
  final String serialNumber;
  final String channel;
  final String? cashierId;
  double? rating;
  String? reviewComment;
  DateTime? ratedAt;
  List<String> reviewMediaUrls;

  OrderModel({
    required this.id,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.orderDate,
    required this.shippingAddress,
    required this.paymentMethod,
    this.trackingNumber = '',
    this.courier = 'JNE Reguler',
    this.warrantyDurationMonths = 24,
    this.serialNumber = 'SN-DC2026-00918',
    this.channel = 'online',
    this.cashierId,
    this.rating,
    this.reviewComment,
    this.ratedAt,
    List<String>? reviewMediaUrls,
  }) : reviewMediaUrls = reviewMediaUrls ?? [];

  DateTime get warrantyExpiryDate =>
      orderDate.add(Duration(days: warrantyDurationMonths * 30));

  bool get isWarrantyActive => DateTime.now().isBefore(warrantyExpiryDate);

  int get remainingWarrantyDays =>
      isWarrantyActive ? warrantyExpiryDate.difference(DateTime.now()).inDays : 0;

  bool get hasRating => rating != null;

  int get daysSinceRating =>
      ratedAt != null ? DateTime.now().difference(ratedAt!).inDays : 999;

  /// Max 7 hari setelah rating diberikan untuk mengubah rating
  bool get canEditRating => hasRating && daysSinceRating <= 7;

  int get remainingEditDays => 7 - daysSinceRating;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items.map((it) => it.toMap()).toList(),
      'total_price': totalPrice,
      'status': status.name,
      'order_date': orderDate.toIso8601String(),
      'shipping_address': shippingAddress,
      'payment_method': paymentMethod,
      'tracking_number': trackingNumber,
      'courier': courier,
      'warranty_months': warrantyDurationMonths,
      'serial_number': serialNumber,
      'channel': channel,
      'cashier_id': cashierId,
      'rating': rating,
      'review_comment': reviewComment,
      'rated_at': ratedAt?.toIso8601String(),
      'review_media_urls': reviewMediaUrls,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    List<CartItemModel> orderItems = [];
    final rawItems = map['items'] ?? map['items_summary'];
    if (rawItems != null) {
      try {
        final list = rawItems is String ? (jsonDecode(rawItems) as List) : (rawItems as List);
        orderItems = list
            .map((item) => CartItemModel.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error decoding order items: $e');
      }
    }

    List<String> mediaUrls = [];
    if (map['review_media_urls'] is List) {
      mediaUrls = (map['review_media_urls'] as List).map((e) => e.toString()).toList();
    }

    OrderStatus parseStatus(dynamic s) {
      if (s is String) {
        switch (s.toLowerCase()) {
          case 'processing': return OrderStatus.processing;
          case 'shipped': return OrderStatus.shipped;
          case 'delivered': return OrderStatus.delivered;
          case 'cancelled': return OrderStatus.cancelled;
        }
      }
      return OrderStatus.processing;
    }

    return OrderModel(
      id: map['id']?.toString() ?? '',
      items: orderItems,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0,
      status: parseStatus(map['status']),
      orderDate: DateTime.tryParse(map['order_date']?.toString() ?? '') ?? DateTime.now(),
      shippingAddress: map['shipping_address']?.toString() ?? '',
      paymentMethod: map['payment_method']?.toString() ?? '',
      trackingNumber: map['tracking_number']?.toString() ?? '',
      courier: map['courier']?.toString() ?? 'JNE Reguler',
      warrantyDurationMonths: (map['warranty_months'] as num?)?.toInt() ?? 24,
      serialNumber: map['serial_number']?.toString() ?? 'SN-DC2026-00918',
      channel: map['channel']?.toString() ?? 'online',
      cashierId: map['cashier_id']?.toString(),
      rating: (map['rating'] as num?)?.toDouble(),
      reviewComment: map['review_comment']?.toString(),
      ratedAt: map['rated_at'] != null ? DateTime.tryParse(map['rated_at'].toString()) : null,
      reviewMediaUrls: mediaUrls,
    );
  }
}
