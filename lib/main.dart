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
import 'package:doctor_computer/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables from .env
    await EnvConfig.init();
  } catch (e) {
    debugPrint('EnvConfig init notice: $e');
  }

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
  authProvider.ensureAdminAccount();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => PcBuilderProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => BlockchainProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
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
