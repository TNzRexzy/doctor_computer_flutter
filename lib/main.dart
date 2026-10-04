import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/pc_builder_provider.dart';
import 'package:doctor_computer/providers/wishlist_provider.dart';
import 'package:doctor_computer/providers/theme_provider.dart';
import 'package:doctor_computer/app.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => PcBuilderProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const DoctorComputerApp(),
    ),
  );
}
