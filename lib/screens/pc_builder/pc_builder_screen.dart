import 'package:doctor_computer/providers/review_provider.dart';
import 'package:doctor_computer/data/models/review_model.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/pc_build_model.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/providers/pc_builder_provider.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/widgets/pc_builder/part_slot_card.dart';
import 'package:doctor_computer/widgets/pc_builder/price_summary_card.dart';
import 'package:doctor_computer/widgets/pc_builder/ai_bottleneck_sheet.dart';
import 'package:doctor_computer/navigation/app_router.dart';

class PcBuilderScreen extends StatelessWidget {
  const PcBuilderScreen({super.key});

  void _showServiceReviewDialog(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu untuk memberikan ulasan jasa rakit.')),
      );
      return;
    }

    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Ulasan Jasa Rakit PC', style: AppTextStyles.titleMedium),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rating Kepuasan Perakitan:', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starVal = (index + 1).toDouble();
                    return IconButton(
                      icon: Icon(
                        starVal <= selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          selectedRating = starVal;
                        });
                      },
                    );
                  }),
                ),
                Center(
                  child: Text(
                    '${selectedRating.toInt()} dari 5 Bintang',
                    style: AppTextStyles.caption.copyWith(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Ulasan Jasa / Teknisi',
                    hintText: 'Tulis pengalaman Anda mengenai kerapihan cable management, kecepatan, dan pengujian QC perakitan...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final comment = commentController.text.trim();
                if (comment.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mohon isi ulasan jasa rakit terlebih dahulu')),
                  );
                  return;
                }

                final newReview = ReviewModel(
                  id: 'rev-service-${DateTime.now().millisecondsSinceEpoch}',
                  userId: user.id,
                  productId: 'build-service-fee',
                  userName: user.fullName,
                  rating: selectedRating,
                  comment: comment,
                  date: DateTime.now(),
                );

                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final success = await context.read<ReviewProvider>().addReview(newReview);
                nav.pop();

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Ulasan jasa rakit berhasil dikirim!' : 'Gagal mengirim ulasan'),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              },
              child: const Text('Kirim Ulasan Jasa'),
            ),
          ],
        ),
      ),
    );
  }

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
                                      'AI Bottleneck Calculator',
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
                          // Service Reviews Section
                          Consumer<ReviewProvider>(
                            builder: (context, reviewProv, _) {
                              final serviceReviews = reviewProv.getReviewsForProduct('build-service-fee');
                              return GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.handyman_outlined, size: 20, color: AppColors.primary),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Ulasan Jasa Rakit (${serviceReviews.length})',
                                              style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.rate_review_outlined, size: 14),
                                          label: const Text('Beri Ulasan Jasa', style: TextStyle(fontSize: 12)),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                          onPressed: () => _showServiceReviewDialog(context),
                                        ),
                                      ],
                                    ),
                                    if (serviceReviews.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'Belum ada ulasan untuk jasa perakitan PC Doctor Computer.',
                                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                                        ),
                                      )
                                    else
                                      ...serviceReviews.take(3).map((r) => Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.surfaceLight),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(r.userName, style: AppTextStyles.titleSmall.copyWith(fontSize: 12)),
                                                  const Spacer(),
                                                  Row(
                                                    children: List.generate(
                                                      5,
                                                      (index) => Icon(
                                                        index < r.rating ? Icons.star : Icons.star_border,
                                                        color: Colors.amber,
                                                        size: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(r.comment, style: AppTextStyles.bodySmall),
                                            ],
                                          ),
                                        ),
                                      )),
                                  ],
                                ),
                              );
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
                                    id: part.id,
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

                              final user = context.read<AuthProvider>().currentUser;
                              if (user != null && user.id.isNotEmpty && user.id != 'guest') {
                                provider.saveBuildToDatabase(user.id);
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


