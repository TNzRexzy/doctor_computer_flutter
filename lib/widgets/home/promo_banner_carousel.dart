import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';

class PromoBannerCarousel extends StatefulWidget {
  PromoBannerCarousel({super.key});

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final PageController _pageController = PageController();
  Timer? _timer;
  
  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Flash Sale! Up to 40% Off',
      'subtitle': 'Diskon hingga 40%',
      'gradient': LinearGradient(
        colors: [AppColors.primary, Color(0xFF0044AA)],
      ),
    },
    {
      'title': 'Build Your Dream PC',
      'subtitle': 'Rakit PC Impianmu',
      'gradient': LinearGradient(
        colors: [AppColors.surface, Color(0xFF0044AA)],
      ),
    },
    {
      'title': 'Free Shipping',
      'subtitle': 'Gratis Ongkir',
      'gradient': LinearGradient(
        colors: [Color(0xFF0044AA), AppColors.accent],
      ),
    },
    {
      'title': 'Member Exclusive Deals',
      'subtitle': 'Promo Khusus Member',
      'gradient': LinearGradient(
        colors: [AppColors.surface, Color(0xFF00B368)],
      ),
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = _pageController.page!.round() + 1;
        if (nextPage == _banners.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: banner['gradient'] as Gradient,
                ),
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      banner['title'] as String,
                      style: AppTextStyles.heading2.copyWith(color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 8),
                    Text(
                      banner['subtitle'] as String,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(height: 12),
        SmoothPageIndicator(
          controller: _pageController,
          count: _banners.length,
          effect: ExpandingDotsEffect(
            activeDotColor: AppColors.primary,
            dotColor: AppColors.cardBorder,
            dotHeight: 8,
            dotWidth: 8,
            expansionFactor: 3,
          ),
        ),
      ],
    );
  }
}


