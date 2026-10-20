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
  double? rating;
  String? reviewComment;
  DateTime? ratedAt;

  OrderModel({
    required this.id,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.orderDate,
    required this.shippingAddress,
    required this.paymentMethod,
    this.trackingNumber = 'JNE-DC98124982',
    this.courier = 'JNE Reguler',
    this.warrantyDurationMonths = 24,
    this.serialNumber = 'SN-DC2026-00918',
    this.rating,
    this.reviewComment,
    this.ratedAt,
  });

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
}
