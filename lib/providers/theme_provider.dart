import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _prefThemeModeKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  /// Memulihkan tema terakhir yang dipilih pengguna. Dipanggil di `main()`
  /// sebelum `runApp` agar aplikasi langsung terbuka dengan tema yang benar.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefThemeModeKey);
      _themeMode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      debugPrint('Error restoring theme mode: $e');
      _themeMode = ThemeMode.light;
    }
    AppColors.isDark = _themeMode == ThemeMode.dark;
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    AppColors.isDark = _themeMode == ThemeMode.dark;
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefThemeModeKey,
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }
}
