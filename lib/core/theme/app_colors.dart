import 'package:flutter/material.dart';

/// Defines all the colors used in the app.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0066FF);
  static const Color primaryLight = Color(0xFF3D8BFF);
  static const Color primaryDark = Color(0xFF0044CC);
  
  static const Color accent = Color(0xFF00D4FF);
  static const Color accentGreen = Color(0xFF00E676);
  
  static const Color background = Color(0xFF0D1117);
  static const Color backgroundLight = Color(0xFF161B22);
  
  static const Color surface = Color(0xFF1C2333);
  static const Color surfaceLight = Color(0xFF242D3D);
  static const Color cardBorder = Color(0xFF2D3748);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B8C8);
  static const Color textTertiary = Color(0xFF6B7B8D);
  
  static const Color error = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFBE21);
  static const Color success = Color(0xFF00E676);
  static const Color discount = Color(0xFFFF4757);
  
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color platinum = Color(0xFFE5E4E2);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, backgroundLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
