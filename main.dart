import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/pc_builder_provider.dart';
import 'package:doctor_computer/providers/wishlist_provider.dart';
import 'package:doctor_computer/providers/theme_provider.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/providers/notification_provider.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/providers/review_provider.dart';
import 'package:doctor_computer/core/config/env_config.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialize notice: $e');
  }

  // Restore authenticated user session before UI build
  final authProvider = AuthProvider();
  await authProvider.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (_) {
            final cp = CartProvider();
            if (authProvider.currentUser?.id != null) {
              cp.setUserId(authProvider.currentUser!.id);
            }
            return cp;
          },
          update: (_, auth, cartProvider) {
            final cp = cartProvider ?? CartProvider();
            final newId = auth.currentUser?.id;
            if (newId != cp.userId) {
              cp.setUserId(newId);
            }
            return cp;
          },
        ),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => PcBuilderProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<AuthProvider, BlockchainProvider>(
          create: (_) {
            final bp = BlockchainProvider();
            if (authProvider.currentUser != null) {
              final u = authProvider.currentUser!;
              bp.initWallet(
                u.id,
                u.fullName,
                isAdmin: u.role == UserRole.admin,
              );
            }
            return bp;
          },
          update: (_, auth, blockchainProvider) {
            final bp = blockchainProvider ?? BlockchainProvider();
            if (auth.currentUser != null) {
              final u = auth.currentUser!;
              if (bp.wallet.userId != u.id) {
                bp.initWallet(
                  u.id,
                  u.fullName,
                  isAdmin: u.role == UserRole.admin,
                );
              }
            } else if (bp.wallet.userId != 'guest') {
              bp.initWallet('guest', 'Pengguna Baru');
            }
            return bp;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) {
            final np = NotificationProvider();
            if (authProvider.currentUser?.id != null) {
              np.setUserId(authProvider.currentUser!.id);
            }
            return np;
          },
          update: (_, auth, notifProvider) {
            final np = notifProvider ?? NotificationProvider();
            final newId = auth.currentUser?.id;
            if (newId != np.userId) {
              np.setUserId(newId);
            }
            return np;
          },
        ),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProxyProvider<AuthProvider, OrderProvider>(
          create: (_) {
            final op = OrderProvider();
            if (authProvider.currentUser?.id != null) {
              op.setUserId(authProvider.currentUser!.id);
            }
            return op;
          },
          update: (_, auth, orderProvider) {
            final op = orderProvider ?? OrderProvider();
            if (auth.currentUser?.id != op.userId) {
              op.setUserId(auth.currentUser?.id);
            }
            return op;
          },
        ),
      ],
      child: const DoctorComputerApp(),
    ),
  );
}
