import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_theme.dart';
import 'package:doctor_computer/navigation/app_router.dart';

class DoctorComputerApp extends StatelessWidget {
  const DoctorComputerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Computer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
