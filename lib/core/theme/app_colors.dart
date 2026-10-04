import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static bool isDark = false; // Default light mode

  // Logo colors:
  // Primary: Amber/Gold #FCA311
  // Secondary: Teal/Cyan #48CAE4
  // Dark bg: #1A1A1A
  // Light bg: #F8F9FA

  static Color get primary => const Color(0xFFFCA311);
  static Color get primaryLight => const Color(0xFFFFD166);
  static Color get primaryDark => const Color(0xFFE88700);
  
  static Color get accent => const Color(0xFF48CAE4);
  static Color get accentGreen => const Color(0xFF00E676);
  
  static Color get background => isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
  static Color get backgroundLight => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  
  static Color get surface => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  static Color get surfaceLight => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F3F5);
  static Color get cardBorder => isDark ? const Color(0xFF333333) : const Color(0xFFE9ECEF);
  
  static Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF212529);
  static Color get textSecondary => isDark ? const Color(0xFFB0B8C8) : const Color(0xFF6C757D);
  static Color get textTertiary => isDark ? const Color(0xFF6B7B8D) : const Color(0xFFADB5BD);
  static Color get buttonText => const Color(0xFF121212); // Always dark on Gold button

  
  static Color get error => const Color(0xFFFF4757);
  static Color get warning => const Color(0xFFFFBE21);
  static Color get success => const Color(0xFF00E676);
  static Color get discount => const Color(0xFFFF4757);
  
  static Color get gold => const Color(0xFFFFD700);
  static Color get silver => const Color(0xFFC0C0C0);
  static Color get bronze => const Color(0xFFCD7F32);
  static Color get platinum => const Color(0xFFE5E4E2);

  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get accentGradient => LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get cardGradient => LinearGradient(
    colors: [surface, backgroundLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
