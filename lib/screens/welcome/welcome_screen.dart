import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/auth_provider.dart';

/// Welcome Screen - shows after successful registration
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final name = user?.fullName ?? 'Pengguna';
    final email = user?.email ?? 'Pengguna';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user,
                size: 120,
                color: AppColors.primary,
              ),
              const SizedBox(height: 40),
              Text(
                'Selamat datang, $name!',
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Email: $email',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // User already set during registration, just navigate to main
                    Navigator.pushReplacementNamed(context, AppRouter.mainNav);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Mulai Pakai Aplikasi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.surface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRouter.login);
                },
                child: Text(
                  'Sudah punya akun? Login',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}