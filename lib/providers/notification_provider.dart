import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/app_notification_model.dart';
import 'package:doctor_computer/navigation/app_router.dart';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotificationModel> _notifications = [
    AppNotificationModel(
      id: 'notif-1',
      title: 'Peringatan Bottleneck PC Terdeteksi',
      message: 'Kombinasi CPU dan GPU Anda berpotensi mengalami bottleneck 26%! Disarankan upgrade CPU ke seri i7 atau Ryzen 7 untuk menyeimbangkan performa.',
      type: NotificationType.bottleneck,
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      isRead: false,
      actionRoute: AppRouter.pcBuilder,
      actionLabel: 'Buka Kalkulator Bottleneck',
    ),
    AppNotificationModel(
      id: 'notif-2',
      title: 'Minigames Reminder: Bonus EXP Menanti!',
      message: 'Waktunya menyelesaikan Memory Match & Kuis PC hari ini! Klaim hingga +250 EXP untuk mempercepat kenaikan Tier Member Anda.',
      type: NotificationType.minigame,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
      actionRoute: AppRouter.membership,
      actionLabel: 'Main Minigames Sekarang',
    ),
    AppNotificationModel(
      id: 'notif-3',
      title: 'Batas Waktu Pembayaran Pesanan',
      message: 'Batas waktu pembayaran pesanan #DC-98412 tinggal 2 jam lagi! Segera selesaikan sebelum pesanan otomatis dibatalkan.',
      type: NotificationType.paymentDeadline,
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      isRead: false,
      actionRoute: AppRouter.orderHistory,
      actionLabel: 'Selesaikan Pembayaran',
    ),
    AppNotificationModel(
      id: 'notif-4',
      title: 'Batas Waktu Voucher Diskon Hangus!',
      message: 'Voucher "UPGRADEPC15" Diskon 15% Member Anda akan hangus besok pukul 23:59 WIB. Jangan lewatkan potongan harga hingga Rp500.000!',
      type: NotificationType.voucherExpiry,
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      isRead: true,
      actionRoute: AppRouter.catalog,
      actionLabel: 'Gunakan Voucher',
    ),
  ];

  List<AppNotificationModel> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void addNotification({
    required String title,
    required String message,
    required String type,
    String? actionRoute,
    String? actionLabel,
  }) {
    NotificationType nType = NotificationType.general;
    if (type == 'bottleneck') nType = NotificationType.bottleneck;
    if (type == 'minigame') nType = NotificationType.minigame;
    if (type == 'payment_deadline') nType = NotificationType.paymentDeadline;
    if (type == 'voucher_expiry') nType = NotificationType.voucherExpiry;
    if (type == 'order') nType = NotificationType.order;
    if (type == 'tier_upgrade') nType = NotificationType.tierUpgrade;

    _notifications.insert(
      0,
      AppNotificationModel(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        message: message,
        type: nType,
        timestamp: DateTime.now(),
        isRead: false,
        actionRoute: actionRoute,
        actionLabel: actionLabel,
      ),
    );
    notifyListeners();
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }
}
