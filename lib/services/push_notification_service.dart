import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/core/navigation/app_navigation.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const _channelId = 'order_updates';
  static const _channelName = 'Pembaruan Pesanan';
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  String? _userId;
  String? _registeredToken;
  bool _initialized = false;
  bool _firebaseReady = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => _openOrderHistory(),
      );
    } catch (error) {
      debugPrint('Local notification initialization failed: $error');
    }
    _initialized = true;

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (_) => _openOrderHistory(),
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        _saveToken,
        onError: (Object error) {
          debugPrint('FCM token refresh failed: $error');
        },
      );
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openOrderHistory(),
        );
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'FCM is not configured; device push is unavailable: ${error.message}',
      );
    } catch (error) {
      debugPrint('FCM initialization failed: $error');
    }
  }

  Future<void> setUserId(String? userId) async {
    if (_userId == userId) return;
    final oldUserId = _userId;
    _userId = userId;
    if (oldUserId != null && _registeredToken != null) {
      try {
        await Supabase.instance.client
            .from('user_push_tokens')
            .delete()
            .eq('user_id', oldUserId)
            .eq('token', _registeredToken!);
      } catch (error) {
        debugPrint('Could not remove previous push token: $error');
      }
      _registeredToken = null;
    }
    if (userId == null) return;

    try {
      if (!_firebaseReady) return;

      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('FCM notification permission was not granted.');
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
    } catch (error) {
      debugPrint(
        'Could not register this device for push notifications: $error',
      );
    }
  }

  Future<void> _saveToken(String token) async {
    final userId = _userId;
    if (userId == null || token.isEmpty) return;

    try {
      await Supabase.instance.client.from('user_push_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
      _registeredToken = token;
    } catch (error) {
      debugPrint('Could not save this device push token: $error');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Pembaruan pesanan';
    final body = message.notification?.body ?? '';
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Informasi perubahan status pesanan.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: '/order-history',
    );
  }

  void _openOrderHistory() {
    appNavigatorKey.currentState?.pushNamed('/order-history');
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
