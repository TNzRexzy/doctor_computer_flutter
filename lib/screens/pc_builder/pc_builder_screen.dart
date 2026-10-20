import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/pc_build_model.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/providers/pc_builder_provider.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/widgets/pc_builder/part_slot_card.dart';
import 'package:doctor_computer/widgets/pc_builder/price_summary_card.dart';
import 'package:doctor_computer/widgets/pc_builder/ai_bottleneck_sheet.dart';
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
                      Text('Rakit PC', style: AppTextStyles.heading3),
                      Text('Pilih komponen', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
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
                final cpu = provider.selectedParts[PcPartCategory.cpu];
                final gpu = provider.selectedParts[PcPartCategory.gpu];
                final ram = provider.selectedParts[PcPartCategory.ram];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Column(
                    children: [
                      // AI Bottleneck Banner
                      InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => AiBottleneckSheet(cpu: cpu, gpu: gpu, ram: ram),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.15),
                                AppColors.accent.withValues(alpha: 0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.speed, color: AppColors.primary, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '🤖 AI Bottleneck Calculator',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      (cpu != null && gpu != null)
                                          ? 'Analisis seimbang: ${cpu.name.split(' ').take(2).join(' ')} + ${gpu.name.split(' ').take(2).join(' ')}'
                                          : 'Pilih CPU & GPU untuk menghitung bottleneck',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Cek AI',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (provider.compatibilityIssues.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
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
                      ],
                    ],
                  ),
                );
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
                          }),
                          const SizedBox(height: 16),
                          PriceSummaryCard(
                            selectedParts: provider.selectedParts,
                            totalPartsPrice: provider.totalPartsPrice,
                            buildFee: provider.buildFee,
                            grandTotal: provider.grandTotal,
                            serviceTier: provider.serviceTier,
                            onServiceTierChanged: (tier) {
                              provider.setServiceTier(tier);
                            },
                          ),
                          const SizedBox(height: 16),
                          GradientButton(
                            label: 'Tambah ke Keranjang',
                            icon: Icons.shopping_cart,
                            isEnabled: provider.selectedParts.containsKey(PcPartCategory.cpu) &&
                                provider.selectedParts.containsKey(PcPartCategory.gpu) &&
                                provider.selectedParts.containsKey(PcPartCategory.motherboard) &&
                                provider.selectedParts.containsKey(PcPartCategory.ram),
                            onPressed: () {
                              final parts = provider.selectedParts;
                              // Add each selected part as a separate cart item
                              final cart = context.read<CartProvider>();
                              
                              int addedCount = 0;
                              for (final entry in parts.entries) {
                                if (entry.value != null) {
                                  final part = entry.value!;
                                  final product = ProductModel(
                                    id: 'build-${part.id}',
                                    name: '${part.name} (Rakit PC)',
                                    description: 'Komponen rakit PC - ${entry.key.displayNameId}',
                                    descriptionId: 'Komponen rakit PC - ${entry.key.displayNameId}',
                                    price: part.price,
                                    categoryId: 'pc-build',
                                    brand: part.brand,
                                    images: part.imageUrl != null ? [part.imageUrl!] : [],
                                    specs: part.specs,
                                    rating: 4.5,
                                    reviewCount: 0,
                                    stock: 10,
                                    isNew: false,
                                    isOnSale: false,
                                  );
                                  cart.addToCart(product);
                                  addedCount++;
                                }
                              }
                              
                              // Also add build service fee as an item
                              if (addedCount > 0) {
                                final serviceName = provider.serviceTier == BuildServiceTier.standard 
                                    ? 'Jasa Rakit PC Standard' 
                                    : 'Jasa Rakit PC Premium';
                                final serviceProduct = ProductModel(
                                  id: 'build-service-fee',
                                  name: serviceName,
                                  description: 'Biaya jasa perakitan PC',
                                  descriptionId: 'Biaya jasa perakitan PC',
                                  price: provider.buildFee,
                                  categoryId: 'service',
                                  brand: 'Doctor Computer',
                                  images: [],
                                  specs: {},
                                  rating: 5.0,
                                  reviewCount: 0,
                                  stock: 999,
                                  isNew: false,
                                  isOnSale: false,
                                );
                                cart.addToCart(serviceProduct);
                              }
                              
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Berhasil!'),
                                  content: Text('$addedCount komponen + jasa rakit berhasil ditambahkan ke keranjang.'),
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


