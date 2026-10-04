import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/data/models/pc_build_model.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';

class PriceSummaryCard extends StatelessWidget {
  final Map<PcPartCategory, PcPartModel?> selectedParts;
  final double totalPartsPrice;
  final double buildFee;
  final double grandTotal;
  final BuildServiceTier serviceTier;
  final Function(BuildServiceTier) onServiceTierChanged;

  const PriceSummaryCard({
    super.key,
    required this.selectedParts,
    required this.totalPartsPrice,
    required this.buildFee,
    required this.grandTotal,
    required this.serviceTier,
    required this.onServiceTierChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeParts = selectedParts.values.where((part) => part != null).cast<PcPartModel>().toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ringkasan Harga / Price Summary', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          if (activeParts.isNotEmpty) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeParts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final part = activeParts[index];
                return Row(
                  children: [
                    const Icon(Icons.memory, size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        part.name,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatRupiah(part.price),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                );
              },
            ),
            const Divider(color: AppColors.cardBorder, height: 24),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal Komponen', style: AppTextStyles.bodyMedium),
              Text(formatRupiah(totalPartsPrice), style: AppTextStyles.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SegmentedButton<BuildServiceTier>(
                  segments: const [
                    ButtonSegment(value: BuildServiceTier.standard, label: Text('Standard')),
                    ButtonSegment(value: BuildServiceTier.premium, label: Text('Premium')),
                  ],
                  selected: {serviceTier},
                  onSelectionChanged: (Set<BuildServiceTier> newSelection) {
                    onServiceTierChanged(newSelection.first);
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    selectedForegroundColor: Colors.white,
                    selectedBackgroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(formatRupiah(buildFee), style: AppTextStyles.titleSmall),
            ],
          ),
          const Divider(color: AppColors.cardBorder, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Estimasi / Estimated Total', style: AppTextStyles.titleMedium),
              Text(
                formatRupiah(grandTotal),
                style: AppTextStyles.heading3.copyWith(color: AppColors.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
