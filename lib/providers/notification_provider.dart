import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/data/models/app_notification_model.dart';

/// Notifikasi per user. Sumber utama: tabel Supabase `user_notifications`
/// (sinkron antar perangkat). SharedPreferences dipakai sebagai cache lokal
/// agar notifikasi tetap tampil saat offline / sebelum data server selesai dimuat.
class NotificationProvider extends ChangeNotifier {
  static const int _maxStored = 100;
  static const String _table = 'user_notifications';

  final List<AppNotificationModel> _notifications = [];
  String? _userId;

  SupabaseClient get _supabase => Supabase.instance.client;

  String? get userId => _userId;

  String get _storageKey => 'user_notifications_$_userId';

  /// Dipanggil saat user login/logout/berganti akun.
  void setUserId(String? id) {
    if (_userId == id) return;
    _userId = id;
    _notifications.clear();
    notifyListeners();
    if (id != null) _loadAll(id);
  }

  // ---------------------------------------------------------------
  // Load: cache lokal dulu (cepat), lalu sinkron dengan Supabase
  // ---------------------------------------------------------------
  Future<void> _loadAll(String forUserId) async {
    await _loadFromCache(forUserId);
    await _syncWithRemote(forUserId);
  }

  Future<void> _loadFromCache(String forUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_notifications_$forUserId');
      if (_userId != forUserId) return;
      if (raw == null || raw.isEmpty) return;
      final List list = jsonDecode(raw);
      final loaded = <AppNotificationModel>[];
      for (final item in list) {
        if (item is Map) {
          final n = AppNotificationModel.fromMap(Map<String, dynamic>.from(item));
          if (n.id.isNotEmpty) loaded.add(n);
        }
      }
      _mergeIn(loaded);
    } catch (e) {
      debugPrint('Error loading notifications cache: $e');
    }
  }

  Future<void> _syncWithRemote(String forUserId) async {
    try {
      final res = await _supabase
          .from(_table)
          .select()
          .eq('user_id', forUserId)
          .order('created_at', ascending: false)
          .limit(_maxStored);
      if (_userId != forUserId) return;

      final remote = <AppNotificationModel>[];
      for (final row in List<Map<String, dynamic>>.from(res)) {
        remote.add(_fromRemote(row));
      }
      final remoteIds = remote.map((n) => n.id).toSet();

      // Notifikasi yang hanya ada di lokal (dibuat saat offline) -> kirim ke server.
      final localOnly =
          _notifications.where((n) => !remoteIds.contains(n.id)).toList();

      // Server adalah sumber utama untuk status baca.
      for (final r in remote) {
        final idx = _notifications.indexWhere((n) => n.id == r.id);
        if (idx >= 0) {
          _notifications[idx].isRead = r.isRead || _notifications[idx].isRead;
        }
      }
      _mergeIn(remote);

      if (localOnly.isNotEmpty) {
        await _supabase
            .from(_table)
            .upsert(localOnly.map((n) => _toRemote(n, forUserId)).toList());
      }
      _saveToCache();
    } catch (e) {
      debugPrint('Error syncing notifications with Supabase: $e');
    }
  }

  void _mergeIn(List<AppNotificationModel> incoming) {
    final existingIds = _notifications.map((n) => n.id).toSet();
    _notifications.addAll(incoming.where((n) => !existingIds.contains(n.id)));
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (_notifications.length > _maxStored) {
      _notifications.removeRange(_maxStored, _notifications.length);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // Mapping lokal <-> tabel Supabase
  // ---------------------------------------------------------------
  Map<String, dynamic> _toRemote(AppNotificationModel n, String uid) {
    return {
      'id': n.id,
      'user_id': uid,
      'title': n.title,
      'message': n.message,
      'type': n.type.name,
      'action_route': n.actionRoute,
      'action_label': n.actionLabel,
      'is_read': n.isRead,
      'created_at': n.timestamp.toUtc().toIso8601String(),
    };
  }

  AppNotificationModel _fromRemote(Map<String, dynamic> row) {
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
    return AppNotificationModel.fromMap({
      'id': row['id'],
      'title': row['title'],
      'message': row['message'],
      'type': row['type'],
      'timestamp': (created?.toLocal() ?? DateTime.now()).toIso8601String(),
      'is_read': row['is_read'],
      'action_route': row['action_route'],
      'action_label': row['action_label'],
    });
  }

  // ---------------------------------------------------------------
  // Cache lokal
  // ---------------------------------------------------------------
  Future<void> _saveToCache() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _notifications.take(_maxStored).map((n) => n.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving notifications cache: $e');
    }
  }

  // ---------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------
  List<AppNotificationModel> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifications[index].isRead = true;
      notifyListeners();
      _saveToCache();
      _remote(() => _supabase
          .from(_table)
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', _userId!));
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
    _saveToCache();
    _remote(() => _supabase
        .from(_table)
        .update({'is_read': true})
        .eq('user_id', _userId!)
        .eq('is_read', false));
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

    final notif = AppNotificationModel(
      id: 'notif-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      message: message,
      type: nType,
      timestamp: DateTime.now(),
      isRead: false,
      actionRoute: actionRoute,
      actionLabel: actionLabel,
    );
    _notifications.insert(0, notif);
    if (_notifications.length > _maxStored) {
      _notifications.removeRange(_maxStored, _notifications.length);
    }
    notifyListeners();
    _saveToCache();
    final uid = _userId;
    if (uid != null) {
      _remote(() => _supabase.from(_table).upsert(_toRemote(notif, uid)));
    }
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    _saveToCache();
    _remote(() => _supabase
        .from(_table)
        .delete()
        .eq('id', id)
        .eq('user_id', _userId!));
  }

  /// Jalankan operasi Supabase tanpa menunggu; gagal (offline/RLS) hanya dicatat.
  /// Item lokal yang belum tersinkron akan dikirim ulang pada sinkronisasi berikutnya.
  void _remote(Future<dynamic> Function() op) {
    if (_userId == null) return;
    () async {
      try {
        await op();
      } catch (e) {
        debugPrint('Notification Supabase sync failed: $e');
      }
    }();
  }
}
