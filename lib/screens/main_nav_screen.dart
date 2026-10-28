import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/screens/home/home_screen.dart';
import 'package:doctor_computer/screens/catalog/catalog_screen.dart';
import 'package:doctor_computer/screens/pc_builder/pc_builder_screen.dart';
import 'package:doctor_computer/screens/cart/cart_screen.dart';
import 'package:doctor_computer/screens/profile/profile_screen.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/widgets/common/bottom_nav_bar.dart';

/// Main Navigation Screen
class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => MainNavScreenState();
}

class MainNavScreenState extends State<MainNavScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _tabTransitionController;

  @override
  void initState() {
    super.initState();
    _tabTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
  }

  @override
  void dispose() {
    _tabTransitionController.dispose();
    super.dispose();
  }

  void switchToTab(int index) {
    if (index < 0 || index >= 5 || index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
    if (MediaQuery.of(context).disableAnimations) {
      _tabTransitionController.value = 1;
    } else {
      _tabTransitionController.forward(from: 0);
    }
  }

  void openCategory(String? categoryId) {
    context.read<ProductProvider>().setCategory(categoryId);
    switchToTab(1);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Scaffold(
      extendBody: true,
      body: AnimatedBuilder(
        animation: _tabTransitionController,
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            HomeScreen(),
            CatalogScreen(),
            PcBuilderScreen(),
            CartScreen(),
            ProfileScreen(),
          ],
        ),
        builder: (context, child) {
          final progress = Curves.easeOutCubic.transform(
            _tabTransitionController.value,
          );
          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, (1 - progress) * 10),
              child: child,
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: switchToTab,
      ),
    );
  }
}
