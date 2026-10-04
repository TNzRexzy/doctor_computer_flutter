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
      case OrderStatus.delivered: return 'Terkirim';
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

/// Represents an order placed by the user.
class OrderModel {
  final String id;
  final List<CartItemModel> items;
  final double totalPrice;
  final OrderStatus status;
  final DateTime orderDate;
  final String shippingAddress;
  final String paymentMethod;

  OrderModel({
    required this.id,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.orderDate,
    required this.shippingAddress,
    required this.paymentMethod,
  });
}
