import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';

enum CompatibilityStatus { compatible, warning, incompatible }

class CompatibilityBadge extends StatelessWidget {
  final String label;
  final CompatibilityStatus status;

  const CompatibilityBadge({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (status) {
      case CompatibilityStatus.compatible:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case CompatibilityStatus.warning:
        color = Colors.amber;
        icon = Icons.warning_rounded;
        break;
      case CompatibilityStatus.incompatible:
        color = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
