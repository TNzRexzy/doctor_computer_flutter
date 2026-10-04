import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';

/// An icon that optionally shows a badge count.
class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final double size;
  final Color? color;

  BadgeIcon({
    super.key,
    required this.icon,
    this.count = 0,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          size: size,
          color: color ?? AppColors.textPrimary,
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}


