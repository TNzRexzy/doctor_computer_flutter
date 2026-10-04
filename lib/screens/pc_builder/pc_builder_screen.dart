import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/providers/pc_builder_provider.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/widgets/pc_builder/part_slot_card.dart';
import 'package:doctor_computer/widgets/pc_builder/price_summary_card.dart';
import 'package:doctor_computer/navigation/app_router.dart';

class PcBuilderScreen extends StatelessWidget {
  const PcBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.build_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rakit PC / PC Builder', style: AppTextStyles.heading3),
                      Text('Pilih komponen / Choose components', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      context.read<PcBuilderProvider>().clearBuild();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Consumer<PcBuilderProvider>(
              builder: (context, provider, child) {
                if (provider.compatibilityIssues.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: provider.compatibilityIssues.map((issue) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: AppColors.error, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(issue, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: Consumer<PcBuilderProvider>(
                builder: (context, provider, child) {
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          ...PcPartCategory.values.map((category) {
                            final selectedPart = provider.selectedParts[category];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: PartSlotCard(
                                category: category,
                                selectedPart: selectedPart,
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRouter.partSelection,
                                    arguments: category,
                                  ).then((result) {
                                    if (result is PcPartModel) {
                                      provider.selectPart(category, result);
                                    }
                                  });
                                },
                                onRemove: () => provider.removePart(category),
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                          PriceSummaryCard(
                            selectedParts: provider.selectedParts,
                            totalPartsPrice: provider.totalPartsPrice,
                            buildFee: provider.buildFee,
                            grandTotal: provider.grandTotal,
                            serviceTier: provider.serviceTier,
                            onServiceTierChanged: (tier) {
                              if (tier != null) provider.setServiceTier(tier);
                            },
                          ),
                          const SizedBox(height: 16),
                          GradientButton(
                            label: 'Tambah ke Keranjang / Add Build to Cart',
                            icon: Icons.shopping_cart,
                            isEnabled: provider.selectedParts.containsKey(PcPartCategory.cpu) &&
                                provider.selectedParts.containsKey(PcPartCategory.gpu) &&
                                provider.selectedParts.containsKey(PcPartCategory.motherboard) &&
                                provider.selectedParts.containsKey(PcPartCategory.ram),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Berhasil / Success'),
                                  content: const Text('Build ditambahkan ke keranjang / Build added to cart'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK'),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


