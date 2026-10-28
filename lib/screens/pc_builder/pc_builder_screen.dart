import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
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

class PcBuilderScreen extends StatefulWidget {
  const PcBuilderScreen({super.key});

  @override
  State<PcBuilderScreen> createState() => _PcBuilderScreenState();
}

class _PcBuilderScreenState extends State<PcBuilderScreen> {
  bool _isSummaryExpanded = true;

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
                      Text(
                        'Pilih komponen',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
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
            Expanded(
              child: Consumer<PcBuilderProvider>(
                builder: (context, provider, child) {
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          ...PcPartCategory.values.map((category) {
                            final selectedPart =
                                provider.selectedParts[category];
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // AI Bottleneck Calculator: dipindah ke bawah, tepat di atas ringkasan harga.
            Consumer<PcBuilderProvider>(
              builder: (context, provider, child) {
                final cpu = provider.selectedParts[PcPartCategory.cpu];
                final gpu = provider.selectedParts[PcPartCategory.gpu];
                final ram = provider.selectedParts[PcPartCategory.ram];

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: Column(
                    children: [
                      // AI Bottleneck Banner
                      InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                AiBottleneckSheet(cpu: cpu, gpu: gpu, ram: ram),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.15),
                                AppColors.accent.withValues(alpha: 0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.speed,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'AI Bottleneck Calculator',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      (cpu != null && gpu != null)
                                          ? 'Analisis seimbang: ${cpu.name.split(' ').take(2).join(' ')} + ${gpu.name.split(' ').take(2).join(' ')}'
                                          : 'Pilih CPU & GPU untuk menghitung bottleneck',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Cek AI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (provider.compatibilityIssues.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: provider.compatibilityIssues.map((issue) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning,
                                      color: AppColors.error,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        issue,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      if (provider.compatibilityWarnings.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: provider.compatibilityWarnings.map((
                              warning,
                            ) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.warning,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        warning,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    ),
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
            // Ringkasan harga: tetap di atas navbar, tidak ikut scroll.
            Consumer<PcBuilderProvider>(
              builder: (context, provider, child) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ringkasan Rakit PC',
                              style: AppTextStyles.titleSmall,
                            ),
                          ),
                          Text(
                            formatRupiah(provider.grandTotal),
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                          IconButton(
                            tooltip: _isSummaryExpanded
                                ? 'Tutup ringkasan'
                                : 'Buka ringkasan',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(
                              () => _isSummaryExpanded = !_isSummaryExpanded,
                            ),
                            icon: AnimatedRotation(
                              turns: _isSummaryExpanded ? 0 : 0.5,
                              duration: const Duration(milliseconds: 220),
                              child: const Icon(Icons.keyboard_arrow_down),
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.topCenter,
                        child: _isSummaryExpanded
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PriceSummaryCard(
                                    compact: true,
                                    selectedParts: provider.selectedParts,
                                    totalPartsPrice: provider.totalPartsPrice,
                                    buildFee: provider.buildFee,
                                    grandTotal: provider.grandTotal,
                                    serviceTier: provider.serviceTier,
                                    onServiceTierChanged: (tier) {
                                      provider.setServiceTier(tier);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  // Tombol tetap di bawah total estimasi (tidak ikut scroll).
                                  GradientButton(
                                    height: 44,
                                    label: 'Tambah ke Keranjang',
                                    icon: Icons.shopping_cart,
                                    isEnabled:
                                        [
                                          PcPartCategory.cpu,
                                          PcPartCategory.gpu,
                                          PcPartCategory.motherboard,
                                          PcPartCategory.ram,
                                        ].every(
                                          (category) =>
                                              provider
                                                  .selectedParts[category] !=
                                              null,
                                        ) &&
                                        provider.compatibilityIssues.isEmpty &&
                                        provider.selectedParts.values
                                            .whereType<PcPartModel>()
                                            .every(
                                              (part) =>
                                                  part.productId?.isNotEmpty ==
                                                  true,
                                            ),
                                    onPressed: () {
                                      final parts = provider.selectedParts;
                                      // Add each selected part as a separate cart item
                                      final cart = context.read<CartProvider>();

                                      int addedCount = 0;
                                      for (final entry in parts.entries) {
                                        if (entry.value != null) {
                                          final part = entry.value!;
                                          final product = ProductModel(
                                            id: part.productId!,
                                            name: '${part.name} (Rakit PC)',
                                            description:
                                                'Komponen rakit PC - ${entry.key.displayNameId}',
                                            descriptionId:
                                                'Komponen rakit PC - ${entry.key.displayNameId}',
                                            price: part.price,
                                            categoryId: 'pc-build',
                                            brand: part.brand,
                                            images: part.imageUrl != null
                                                ? [part.imageUrl!]
                                                : [],
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
                                        final serviceName =
                                            provider.serviceTier ==
                                                BuildServiceTier.standard
                                            ? 'Jasa Rakit PC Standard'
                                            : 'Jasa Rakit PC Premium';
                                        final serviceProduct = ProductModel(
                                          id:
                                              provider.serviceTier ==
                                                  BuildServiceTier.standard
                                              ? 'build-service-standard'
                                              : 'build-service-premium',
                                          name: serviceName,
                                          description:
                                              'Biaya jasa perakitan PC',
                                          descriptionId:
                                              'Biaya jasa perakitan PC',
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
                                          content: Text(
                                            '$addedCount komponen + jasa rakit berhasil ditambahkan ke keranjang.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
