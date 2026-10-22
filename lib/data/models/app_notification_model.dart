import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';

enum NotificationType {
  bottleneck,
  minigame,
  paymentDeadline,
  voucherExpiry,
  order,
  tierUpgrade,
  general,
}

class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;
  final String? actionRoute;
  final String? actionLabel;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.actionRoute,
    this.actionLabel,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.bottleneck:
        return Icons.speed;
      case NotificationType.minigame:
        return Icons.videogame_asset;
      case NotificationType.paymentDeadline:
        return Icons.access_time_filled;
      case NotificationType.voucherExpiry:
        return Icons.confirmation_number;
      case NotificationType.order:
        return Icons.local_shipping;
      case NotificationType.tierUpgrade:
        return Icons.military_tech;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color get iconColor {
    switch (type) {
      case NotificationType.bottleneck:
        return AppColors.error;
      case NotificationType.minigame:
        return Colors.purpleAccent;
      case NotificationType.paymentDeadline:
        return AppColors.warning;
      case NotificationType.voucherExpiry:
        return Colors.amber;
      case NotificationType.order:
        return AppColors.primary;
      case NotificationType.tierUpgrade:
        return AppColors.gold;
      case NotificationType.general:
        return AppColors.primary;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'action_route': actionRoute,
      'action_label': actionLabel,
    };
  }

  factory AppNotificationModel.fromMap(Map<String, dynamic> map) {
    NotificationType parseType(dynamic t) {
      if (t is String) {
        for (final val in NotificationType.values) {
          if (val.name == t) return val;
        }
      }
      return NotificationType.general;
    }

    return AppNotificationModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      type: parseType(map['type']),
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isRead: map['is_read'] as bool? ?? false,
      actionRoute: map['action_route']?.toString(),
      actionLabel: map['action_label']?.toString(),
    );
  }
}
