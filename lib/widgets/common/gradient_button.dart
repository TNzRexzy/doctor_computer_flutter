import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';

/// A reusable gradient button with an optional icon and loading state.
class GradientButton extends StatelessWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double height;
  final IconData? icon;

  const GradientButton({
    super.key,
    this.label,
    this.child,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height = 52,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool canPress = isEnabled && !isLoading;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: canPress
            ? AppColors.primaryGradient
            : null,
        color: canPress ? null : AppColors.cardBorder,
        boxShadow: canPress
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: canPress ? onPressed : null,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : child ??
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        if (label != null)
                          Text(
                            label!,
                            style: AppTextStyles.label.copyWith(
                              color: canPress
                                  ? Colors.white
                                  : AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}
