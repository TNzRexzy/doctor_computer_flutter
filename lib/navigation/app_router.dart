import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';

import 'package:doctor_computer/screens/splash/splash_screen.dart';
import 'package:doctor_computer/screens/onboarding/onboarding_screen.dart';
import 'package:doctor_computer/screens/auth/login_screen.dart';
import 'package:doctor_computer/screens/auth/register_screen.dart';
import 'package:doctor_computer/screens/main_nav_screen.dart';
import 'package:doctor_computer/screens/welcome/welcome_screen.dart';
import 'package:doctor_computer/screens/catalog/catalog_screen.dart';
import 'package:doctor_computer/screens/catalog/product_detail_screen.dart';
import 'package:doctor_computer/screens/search/search_screen.dart';
import 'package:doctor_computer/screens/pc_builder/pc_builder_screen.dart';
import 'package:doctor_computer/screens/pc_builder/part_selection_screen.dart';
import 'package:doctor_computer/screens/cart/cart_screen.dart';
import 'package:doctor_computer/screens/cart/checkout_screen.dart';
import 'package:doctor_computer/screens/profile/profile_screen.dart';
import 'package:doctor_computer/screens/profile/edit_profile_screen.dart';
import 'package:doctor_computer/screens/profile/order_history_screen.dart';
import 'package:doctor_computer/screens/profile/security_settings_screen.dart';
import 'package:doctor_computer/screens/wishlist/wishlist_screen.dart';
import 'package:doctor_computer/screens/member/member_screen.dart';
import 'package:doctor_computer/screens/member/blockchain_ledger_screen.dart';
import 'package:doctor_computer/screens/notifications/notifications_screen.dart';
import 'package:doctor_computer/screens/ai_chat/ai_customer_service_screen.dart';
import 'package:doctor_computer/screens/warranty/warranty_check_screen.dart';
import 'package:doctor_computer/screens/admin/admin_dashboard_screen.dart';
import 'package:doctor_computer/screens/map/location_picker_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String welcome = '/welcome';
  static const String mainNav = '/main';
  static const String catalog = '/catalog';
  static const String productDetail = '/product-detail';
  static const String search = '/search';
  static const String pcBuilder = '/pc-builder';
  static const String partSelection = '/part-selection';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String securitySettings = '/security-settings';
  static const String membership = '/membership';
  static const String orderHistory = '/order-history';
  static const String wishlist = '/wishlist';
  static const String member = '/member';
  static const String blockchainLedger = '/blockchain-ledger';
  static const String notifications = '/notifications';
  static const String aiChat = '/ai-chat';
  static const String warranty = '/warranty';
  static const String adminDashboard = '/admin-dashboard';
  static const String locationPicker = '/location-picker';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen(), settings: settings);
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen(), settings: settings);
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen(), settings: settings);
      case mainNav:
        return MaterialPageRoute(builder: (_) => const MainNavScreen(), settings: settings);
      case catalog:
        final categoryId = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) => CatalogScreen(categoryId: categoryId), settings: settings);
      case productDetail:
        final product = settings.arguments as ProductModel;
        return MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product), settings: settings);
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen(), settings: settings);
      case pcBuilder:
        return MaterialPageRoute(builder: (_) => const PcBuilderScreen(), settings: settings);
      case partSelection:
        final category = settings.arguments as PcPartCategory;
        return MaterialPageRoute(builder: (_) => PartSelectionScreen(category: category), settings: settings);
      case cart:
        return MaterialPageRoute(builder: (_) => const CartScreen(), settings: settings);
      case checkout:
        return MaterialPageRoute(builder: (_) => const CheckoutScreen(), settings: settings);
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen(), settings: settings);
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen(), settings: settings);
      case securitySettings:
        return MaterialPageRoute(builder: (_) => const SecuritySettingsScreen(), settings: settings);
      case membership:
        return MaterialPageRoute(builder: (_) => const MemberScreen(), settings: settings);
      case orderHistory:
        return MaterialPageRoute(builder: (_) => const OrderHistoryScreen(), settings: settings);
      case wishlist:
        return MaterialPageRoute(builder: (_) => const WishlistScreen(), settings: settings);
      case member:
        return MaterialPageRoute(builder: (_) => const MemberScreen(), settings: settings);
      case blockchainLedger:
        return MaterialPageRoute(builder: (_) => const BlockchainLedgerScreen(), settings: settings);
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen(), settings: settings);
      case aiChat:
        return MaterialPageRoute(builder: (_) => const AiCustomerServiceScreen(), settings: settings);
      case warranty:
        return MaterialPageRoute(builder: (_) => const WarrantyCheckScreen(), settings: settings);
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen(), settings: settings);
      case locationPicker:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LocationPickerScreen(
            initialLat: args?['lat'] as double?,
            initialLng: args?['lng'] as double?,
            initialAddress: args?['address'] as String?,
          ),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('404 Not Found')),
          ),
        );
    }
  }
}
