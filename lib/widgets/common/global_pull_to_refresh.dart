import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/providers/pc_builder_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/review_provider.dart';

/// Daftar fungsi refresh milik halaman yang menyimpan datanya sendiri
/// (mis. dashboard admin/kasir). Halaman mendaftar di `initState` dan
/// melepas di `dispose`; semuanya ikut dijalankan saat layar ditarik ke bawah.
class PageRefreshRegistry {
  PageRefreshRegistry._();

  static final List<Future<void> Function()> _callbacks = [];

  static void register(Future<void> Function() callback) {
    if (!_callbacks.contains(callback)) _callbacks.add(callback);
  }

  static void unregister(Future<void> Function() callback) {
    _callbacks.remove(callback);
  }
}

/// Membuat semua daftar/halaman bisa ditarik ke bawah, termasuk yang
/// isinya lebih pendek dari layar, dan mengizinkan tarik lewat mouse/trackpad
/// (Web & Windows).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.mouse,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return AlwaysScrollableScrollPhysics(parent: super.getScrollPhysics(context));
  }
}

/// Tarik layar ke bawah (dari posisi paling atas) di halaman mana pun untuk
/// memuat ulang data aplikasi. Dipasang sekali di `MaterialApp.builder`.
///
/// Halaman yang sudah punya `RefreshIndicator` sendiri tetap memakai miliknya
/// (tidak dobel).
class GlobalPullToRefresh extends StatelessWidget {
  final Widget child;

  const GlobalPullToRefresh({super.key, required this.child});

  /// Hanya gestur vertikal, dan hanya jika tidak ada RefreshIndicator lain
  /// di antara daftar yang ditarik dan indikator global ini.
  static bool _shouldHandle(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final scrollContext = notification.context;
    if (scrollContext == null) return true;
    var indicators = 0;
    scrollContext.visitAncestorElements((element) {
      if (element.widget is RefreshIndicator) indicators++;
      return indicators < 2;
    });
    return indicators < 2;
  }

  Future<void> _refresh(BuildContext context) async {
    final tasks = <Future<void> Function()>[
      context.read<ProductProvider>().reloadData,
      context.read<PcBuilderProvider>().reloadParts,
      context.read<OrderProvider>().reloadOrders,
      context.read<ReviewProvider>().refresh,
      context.read<CartProvider>().refreshPrices,
      context.read<BlockchainProvider>().refreshWallet,
      ...List<Future<void> Function()>.from(PageRefreshRegistry._callbacks),
    ];

    await Future.wait(
      tasks.map((task) async {
        try {
          await task();
        } catch (e) {
          debugPrint('Pull-to-refresh task failed: $e');
        }
      }),
    ).timeout(const Duration(seconds: 20), onTimeout: () => const []);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      edgeOffset: MediaQuery.of(context).padding.top,
      notificationPredicate: _shouldHandle,
      onRefresh: () => _refresh(context),
      child: child,
    );
  }
}
