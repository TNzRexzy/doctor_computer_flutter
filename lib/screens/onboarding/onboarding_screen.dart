import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';

/// Onboarding Screen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.login);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                children: [
                  _buildPage(
                    icon: Icons.shopping_bag_rounded,
                    color: AppColors.primary,
                    title: 'Belanja Komputer Mudah',
                    subtitle: 'Easy Computer Shopping\nTemukan laptop, aksesoris, dan komponen PC terbaik dengan harga kompetitif',
                  ),
                  _buildPage(
                    icon: Icons.build_rounded,
                    color: AppColors.accent,
                    title: 'Rakit PC Impianmu',
                    subtitle: 'Build Your Dream PC\nKonfigurator PC interaktif dengan pengecekan kompatibilitas otomatis',
                  ),
                  _buildPage(
                    icon: Icons.card_membership_rounded,
                    color: AppColors.success,
                    title: 'Member & Rewards',
                    subtitle: 'Membership & Rewards\nDapatkan poin dari setiap pembelian dan nikmati diskon eksklusif',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: 3,
                    effect: ExpandingDotsEffect(
                      dotColor: AppColors.surfaceLight,
                      activeDotColor: AppColors.primary,
                      dotHeight: 8,
                      dotWidth: 8,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_currentIndex < 2)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            'Lewati / Skip',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                        GradientButton(
                          label: 'Lanjut / Next',
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        label: 'Mulai Belanja / Start Shopping',
                        onPressed: _completeOnboarding,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(icon, size: 100, color: color),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: AppTextStyles.heading2.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
