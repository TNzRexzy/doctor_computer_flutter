import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/data/models/app_notification_model.dart';
import 'package:doctor_computer/navigation/app_router.dart';

class NotificationProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  static const String _prefReadNotifsKey = 'user_read_notifications_ids';
  static const String _prefCustomNotifsKey = 'user_custom_notifications';

  final List<AppNotificationModel> _notifications = [];
  String? _userId;
  bool _isLoading = false;

  List<AppNotificationModel> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;

  NotificationProvider() {
    final currentUserId = supabase.auth.currentUser?.id;
    loadNotifications(userId: currentUserId);
  }

  void setUserId(String? userId) {
    if (_userId == userId && _notifications.isNotEmpty) return;
    _userId = userId;
    loadNotifications(userId: userId);
  }

  /// Loads notifications entirely from database entities (Orders, Flash Sales, Member Tiers)
  Future<void> loadNotifications({String? userId}) async {
    _userId = userId ?? _userId ?? supabase.auth.currentUser?.id;
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> readIds = prefs.getStringList(_prefReadNotifsKey) ?? [];
      final Set<String> readSet = readIds.toSet();

      final List<AppNotificationModel> loaded = [];

      // 1. Fetch real orders from Supabase for this user
      if (_userId != null && _userId!.isNotEmpty && _userId != 'guest') {
        try {
          final List ordersRes = await supabase
              .from('orders')
              .select('id, status, total_price, order_date')
              .eq('user_id', _userId!)
              .order('order_date', ascending: false)
              .limit(5);

          for (final o in ordersRes) {
            final orderId = o['id']?.toString() ?? '';
            final status = (o['status']?.toString() ?? 'processing').toLowerCase();
            final orderDate = DateTime.tryParse(o['order_date']?.toString() ?? '') ?? DateTime.now();

            String title = 'Status Pesanan #$orderId';
            String msg = 'Pesanan Anda saat ini berstatus $status.';
            NotificationType type = NotificationType.order;

            if (status == 'delivered') {
              title = 'Pesanan #$orderId Telah Selesai!';
              msg = 'Barang pesanan Anda telah sampai di tujuan. Cek garansi atau berikan ulasan sekarang.';
            } else if (status == 'shipped') {
              title = 'Pesanan #$orderId Sedang Dikirim';
              msg = 'Paket pesanan Anda sedang dalam perjalanan bersama kurir ekspedisi.';
            } else if (status == 'processing') {
              title = 'Pesanan #$orderId Sedang Diproses';
              msg = 'Tim teknisi Doctor Computer sedang mempersiapkan dan menguji komponen pesanan Anda.';
            } else if (status == 'cancelled') {
              title = 'Pesanan #$orderId Dibatalkan';
              msg = 'Pesanan ini telah dibatalkan.';
              type = NotificationType.paymentDeadline;
            }

            final notifId = 'order-$orderId-$status';
            loaded.add(
              AppNotificationModel(
                id: notifId,
                title: title,
                message: msg,
                type: type,
                timestamp: orderDate,
                isRead: readSet.contains(notifId),
                actionRoute: AppRouter.orderHistory,
                actionLabel: 'Lihat Riwayat Pesanan',
              ),
            );
          }
        } catch (e) {
          debugPrint('Notice loading order notifications: $e');
        }

        // 2. Fetch User Membership status from Supabase
        try {
          final userRes = await supabase
              .from('users')
              .select('membership_tier, points')
              .eq('id', _userId!)
              .maybeSingle();

          if (userRes != null) {
            final tier = (userRes['membership_tier']?.toString() ?? 'bronze').toUpperCase();
            final points = (userRes['points'] as num? ?? 0).toInt();

            final notifId = 'tier-$_userId-$tier';
            loaded.add(
              AppNotificationModel(
                id: notifId,
                title: 'Status Member $tier Aktif',
                message: 'Anda memiliki saldo $points Poin Doctor Computer. Nikmati keuntungan dan diskon tier Anda!',
                type: NotificationType.tierUpgrade,
                timestamp: DateTime.now().subtract(const Duration(hours: 1)),
                isRead: readSet.contains(notifId),
                actionRoute: AppRouter.membership,
                actionLabel: 'Lihat Keuntungan Tier',
              ),
            );
          }
        } catch (e) {
          debugPrint('Notice loading user tier notification: $e');
        }
      }

      // 3. Fetch Active Flash Deals from Supabase Products Table
      try {
        final List saleProducts = await supabase
            .from('products')
            .select('id, name, price, original_price')
            .eq('is_on_sale', true)
            .limit(3);

        for (final p in saleProducts) {
          final pid = p['id']?.toString() ?? '';
          final pName = p['name']?.toString() ?? 'Komponen PC';
          final notifId = 'promo-$pid';

          loaded.add(
            AppNotificationModel(
              id: notifId,
              title: 'Flash Sale: $pName!',
              message: 'Penawaran terbatas untuk produk $pName dengan potongan harga spesial hari ini.',
              type: NotificationType.voucherExpiry,
              timestamp: DateTime.now().subtract(const Duration(hours: 3)),
              isRead: readSet.contains(notifId),
              actionRoute: AppRouter.catalog,
              actionLabel: 'Beli Sekarang',
            ),
          );
        }
      } catch (e) {
        debugPrint('Notice loading flash sale notifications: $e');
      }

      // 4. Load any local custom notifications
      try {
        final customJson = prefs.getString(_prefCustomNotifsKey);
        if (customJson != null && customJson.isNotEmpty) {
          final List list = jsonDecode(customJson);
          for (final item in list) {
            final model = AppNotificationModel.fromMap(item as Map<String, dynamic>);
            if (readSet.contains(model.id)) {
              model.isRead = true;
            }
            loaded.add(model);
          }
        }
      } catch (e) {
        debugPrint('Notice loading custom notifications: $e');
      }

      // Sort by latest timestamp
      loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      _notifications.clear();
      _notifications.addAll(loaded);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifications[index].isRead = true;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        final List<String> readIds = prefs.getStringList(_prefReadNotifsKey) ?? [];
        if (!readIds.contains(id)) {
          readIds.add(id);
          await prefs.setStringList(_prefReadNotifsKey, readIds);
        }
      } catch (e) {
        debugPrint('Error saving read notification: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final allIds = _notifications.map((n) => n.id).toList();
      await prefs.setStringList(_prefReadNotifsKey, allIds);
    } catch (e) {
      debugPrint('Error saving all read notifications: $e');
    }
  }

  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    String? actionRoute,
    String? actionLabel,
  }) async {
    NotificationType nType = NotificationType.general;
    if (type == 'bottleneck') nType = NotificationType.bottleneck;
    if (type == 'minigame') nType = NotificationType.minigame;
    if (type == 'payment_deadline') nType = NotificationType.paymentDeadline;
    if (type == 'voucher_expiry') nType = NotificationType.voucherExpiry;
    if (type == 'order') nType = NotificationType.order;
    if (type == 'tier_upgrade') nType = NotificationType.tierUpgrade;

    final newNotif = AppNotificationModel(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: nType,
      timestamp: DateTime.now(),
      isRead: false,
      actionRoute: actionRoute,
      actionLabel: actionLabel,
    );

    _notifications.insert(0, newNotif);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      List<dynamic> list = [];
      final customJson = prefs.getString(_prefCustomNotifsKey);
      if (customJson != null && customJson.isNotEmpty) {
        list = jsonDecode(customJson);
      }
      list.insert(0, newNotif.toMap());
      await prefs.setString(_prefCustomNotifsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving custom notification: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final customJson = prefs.getString(_prefCustomNotifsKey);
      if (customJson != null && customJson.isNotEmpty) {
        final List list = jsonDecode(customJson);
        list.removeWhere((item) => item['id'] == id);
        await prefs.setString(_prefCustomNotifsKey, jsonEncode(list));
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }
}
