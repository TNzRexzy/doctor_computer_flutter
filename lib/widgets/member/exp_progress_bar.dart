import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';

class ExpProgressBar extends StatelessWidget {
  final double progress;
  final String currentLevel;
  final String? nextLevel;

  const ExpProgressBar({
    super.key,
    required this.progress,
    required this.currentLevel,
    this.nextLevel,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * clamped,
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(currentLevel, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            Text('${(clamped * 100).toInt()}%', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
            if (nextLevel != null)
              Text(nextLevel!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}