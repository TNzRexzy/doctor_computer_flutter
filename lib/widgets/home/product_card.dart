import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onWishlistTap;
  final bool isWishlisted;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onWishlistTap,
    this.isWishlisted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.surface, AppColors.surfaceLight],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.computer_rounded, // fallback icon
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              if (product.hasDiscount)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '-${product.discountPercentage.toStringAsFixed(0)}%',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: Icon(
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    color: isWishlisted ? AppColors.error : AppColors.textTertiary,
                  ),
                  onPressed: onWishlistTap,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  product.brand,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatRupiah(product.price),
                            style: AppTextStyles.priceSmall,
                          ),
                          if (product.hasDiscount)
                            Text(
                              formatRupiah(product.originalPrice ?? 0),
                              style: AppTextStyles.priceOriginal,
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toString(),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
