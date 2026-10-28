import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/providers/theme_provider.dart';
import 'package:doctor_computer/core/theme/app_theme.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/widgets/ai_chat/doctor_ai_floating.dart';
import 'package:doctor_computer/widgets/common/global_pull_to_refresh.dart';
import 'package:doctor_computer/core/navigation/app_navigation.dart';

class DoctorComputerApp extends StatelessWidget {
  const DoctorComputerApp({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Doctor Computer',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          scrollBehavior: const AppScrollBehavior(),
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          initialRoute: AppRouter.splash,
          onGenerateRoute: AppRouter.generateRoute,
          navigatorObservers: [DoctorAiRouteObserver.instance],
          builder: (context, child) => GlobalPullToRefresh(
            child: DoctorAiFloatingHost(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
