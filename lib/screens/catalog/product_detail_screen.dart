import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/mock/mock_products.dart';
import 'package:doctor_computer/providers/wishlist_provider.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/data/mock/mock_pc_parts.dart';

/// Product Detail Screen
class ProductDetailScreen extends StatelessWidget {
  final ProductModel product;

  ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final reviews = mockReviews.where((r) => r.productId == product.id).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.surfaceLight, AppColors.surface],
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.computer, size: 100, color: AppColors.primary),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -20),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassCard(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(product.brand, style: AppTextStyles.label.copyWith(color: AppColors.primary)),
                              ),
                              SizedBox(height: 8),
                              Text(product.name, style: AppTextStyles.heading3),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '${product.rating} (${product.reviewCount} reviews)',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(formatRupiah(product.price), style: AppTextStyles.price),
                                      if (product.hasDiscount)
                                        Row(
                                          children: [
                                            Text(
                                              formatRupiah(product.originalPrice ?? 0),
                                              style: AppTextStyles.priceOriginal,
                                            ),
                                            SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.error.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${product.discountPercentage.toStringAsFixed(0)}% OFF',
                                                style: AppTextStyles.label.copyWith(color: AppColors.error),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  Spacer(),
                                  if (product.stock < 10)
                                    Text('Stok tersisa: ${product.stock}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        Text('Spesifikasi / Specifications', style: AppTextStyles.titleMedium),
                        SizedBox(height: 8),
                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: product.specs.entries.map((e) {
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
                                ),
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(e.key, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(e.value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text('Deskripsi / Description', style: AppTextStyles.titleMedium),
                        SizedBox(height: 8),
                        Text(product.descriptionId, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                        SizedBox(height: 16),
                        Text('Ulasan / Reviews', style: AppTextStyles.titleMedium),
                        SizedBox(height: 8),
                        ...reviews.take(3).map((r) => Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: GlassCard(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(r.userName, style: AppTextStyles.titleSmall),
                                    Spacer(),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (index) => Icon(
                                          index < r.rating ? Icons.star : Icons.star_border,
                                          color: Colors.amber,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  r.date.toString().substring(0, 10),
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                                ),
                                SizedBox(height: 8),
                                Text(r.comment, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        )),
                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: CircleAvatar(
              backgroundColor: AppColors.surface.withValues(alpha: 0.5),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: CircleAvatar(
              backgroundColor: AppColors.surface.withValues(alpha: 0.5),
              child: IconButton(
                icon: Icon(Icons.share, color: AppColors.textPrimary),
                onPressed: () {},
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            right: 16,
            child: CircleAvatar(
              backgroundColor: AppColors.surface.withValues(alpha: 0.5),
              child: Consumer<WishlistProvider>(
                builder: (context, provider, child) {
                  final isWishlisted = provider.isInWishlist(product.id);
                  return IconButton(
                    icon: Icon(
                      isWishlisted ? Icons.favorite : Icons.favorite_border,
                      color: isWishlisted ? AppColors.error : AppColors.textPrimary,
                    ),
                    onPressed: () {
                      provider.toggleWishlist(product);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        color: AppColors.surface,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: GradientButton(
                label: 'Tambah ke Keranjang / Add to Cart',
                icon: Icons.shopping_cart,
                onPressed: () {
                  context.read<CartProvider>().addToCart(product);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ditambahkan ke keranjang / Added to cart')),
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



