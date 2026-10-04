import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';

import 'package:doctor_computer/screens/splash/splash_screen.dart';
import 'package:doctor_computer/screens/onboarding/onboarding_screen.dart';
import 'package:doctor_computer/screens/auth/login_screen.dart';
import 'package:doctor_computer/screens/auth/register_screen.dart';
import 'package:doctor_computer/screens/main_nav_screen.dart';
import 'package:doctor_computer/screens/catalog/catalog_screen.dart';
import 'package:doctor_computer/screens/catalog/product_detail_screen.dart';
import 'package:doctor_computer/screens/search/search_screen.dart';
import 'package:doctor_computer/screens/pc_builder/pc_builder_screen.dart';
import 'package:doctor_computer/screens/pc_builder/part_selection_screen.dart';
import 'package:doctor_computer/screens/cart/cart_screen.dart';
import 'package:doctor_computer/screens/cart/checkout_screen.dart';
import 'package:doctor_computer/screens/profile/profile_screen.dart';
import 'package:doctor_computer/screens/profile/edit_profile_screen.dart';
import 'package:doctor_computer/screens/profile/membership_screen.dart';
import 'package:doctor_computer/screens/profile/order_history_screen.dart';
import 'package:doctor_computer/screens/wishlist/wishlist_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
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
  static const String membership = '/membership';
  static const String orderHistory = '/order-history';
  static const String wishlist = '/wishlist';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case mainNav:
        return MaterialPageRoute(builder: (_) => const MainNavScreen());
      case catalog:
        final categoryId = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) => CatalogScreen(categoryId: categoryId));
      case productDetail:
        final product = settings.arguments as ProductModel;
        return MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product));
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case pcBuilder:
        return MaterialPageRoute(builder: (_) => const PcBuilderScreen());
      case partSelection:
        final category = settings.arguments as PcPartCategory;
        return MaterialPageRoute(builder: (_) => PartSelectionScreen(category: category));
      case cart:
        return MaterialPageRoute(builder: (_) => const CartScreen());
      case checkout:
        return MaterialPageRoute(builder: (_) => const CheckoutScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());
      case membership:
        return MaterialPageRoute(builder: (_) => const MembershipScreen());
      case orderHistory:
        return MaterialPageRoute(builder: (_) => const OrderHistoryScreen());
      case wishlist:
        return MaterialPageRoute(builder: (_) => const WishlistScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('404 Not Found')),
          ),
        );
    }
  }
}
