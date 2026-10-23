import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/security_provider.dart';
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
        ChangeNotifierProxyProvider<AuthProvider, SecurityProvider>(
          create: (_) {
            final sp = SecurityProvider();
            if (authProvider.currentUser?.id != null) {
              sp.loadSettings(authProvider.currentUser!.id);
            }
            return sp;
          },
          update: (_, auth, secProvider) {
            final sp = secProvider ?? SecurityProvider();
            if (auth.currentUser?.id != null) {
              if (sp.settings.userId != auth.currentUser!.id) {
                sp.loadSettings(auth.currentUser!.id);
              }
            } else if (sp.settings.userId.isNotEmpty) {
              sp.reset();
            }
            return sp;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, BlockchainProvider>(
          create: (_) {
            final bp = BlockchainProvider();
            if (authProvider.currentUser != null) {
              final u = authProvider.currentUser!;
              bp.initWallet(
                u.id,
                u.fullName,
                isAdmin: u.role == UserRole.admin,
                initialExp: u.points,
                initialTierName: u.membershipTier.name,
              );
            }
            return bp;
          },
          update: (_, auth, blockchainProvider) {
            final bp = blockchainProvider ?? BlockchainProvider();
            
            // Bridge: whenever blockchain wallet syncs or changes, update AuthProvider
            bp.onWalletSynced = (exp, tierName) {
              if (auth.currentUser != null && auth.currentUser!.id == bp.wallet.userId) {
                final tierEnum = auth.parseMembershipTier(tierName);
                if (exp > auth.currentUser!.points ||
                    (auth.currentUser!.points == exp && auth.currentUser!.membershipTier != tierEnum)) {
                  auth.updatePointsAndTier(exp, tierEnum);
                }
              }
            };

            if (auth.currentUser != null) {
              final u = auth.currentUser!;
              if (bp.wallet.userId != u.id) {
                bp.initWallet(
                  u.id,
                  u.fullName,
                  isAdmin: u.role == UserRole.admin,
                  initialExp: u.points,
                  initialTierName: u.membershipTier.name,
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
            if (auth.currentUser?.id != null) {
              np.setUserId(auth.currentUser!.id);
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
