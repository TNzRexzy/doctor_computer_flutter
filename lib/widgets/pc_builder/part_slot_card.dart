import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';

class PartSlotCard extends StatelessWidget {
  final PcPartCategory category;
  final PcPartModel? selectedPart;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const PartSlotCard({
    super.key,
    required this.category,
    this.selectedPart,
    required this.onTap,
    this.onRemove,
  });

  String _getCategoryName(PcPartCategory cat) {
    return cat.name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (selectedPart != null) {
      return GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPart!.name,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedPart!.brand,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(selectedPart!.price),
                    style: AppTextStyles.priceSmall,
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textTertiary),
                onPressed: onRemove,
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          // Simplified dashed border effect
          border: Border.all(
            color: AppColors.cardBorder,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih ${_getCategoryName(category)} / Select ${_getCategoryName(category)}',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to choose',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
