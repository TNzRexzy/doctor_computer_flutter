import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/providers/theme_provider.dart';
import 'package:doctor_computer/core/theme/app_theme.dart';
import 'package:doctor_computer/navigation/app_router.dart';

class DoctorComputerApp extends StatelessWidget {
  const DoctorComputerApp({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Doctor Computer',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          initialRoute: AppRouter.splash,
          onGenerateRoute: AppRouter.generateRoute,
        );
      },
    );
  }
}

