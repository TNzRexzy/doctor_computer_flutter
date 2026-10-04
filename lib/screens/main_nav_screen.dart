import 'package:flutter/material.dart';
import 'package:doctor_computer/screens/home/home_screen.dart';
import 'package:doctor_computer/screens/catalog/catalog_screen.dart';
import 'package:doctor_computer/screens/pc_builder/pc_builder_screen.dart';
import 'package:doctor_computer/screens/cart/cart_screen.dart';
import 'package:doctor_computer/screens/profile/profile_screen.dart';
import 'package:doctor_computer/widgets/common/bottom_nav_bar.dart';

/// Main Navigation Screen
class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          CatalogScreen(),
          PcBuilderScreen(),
          CartScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() {
            _currentIndex = i;
          });
        },
      ),
    );
  }
}

