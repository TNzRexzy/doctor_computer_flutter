import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    AppColors.isDark = _themeMode == ThemeMode.dark;
    notifyListeners();
  }
}
