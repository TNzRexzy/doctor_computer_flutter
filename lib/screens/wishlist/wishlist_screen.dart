import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/wishlist_provider.dart';
import 'package:doctor_computer/widgets/home/product_card.dart';
import 'package:doctor_computer/navigation/app_router.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text('Wishlist', style: AppTextStyles.heading3),
                  const Spacer(),
                  Consumer<WishlistProvider>(
                    builder: (context, provider, child) {
                      return Text('(${provider.itemCount} items)', style: AppTextStyles.bodySmall);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<WishlistProvider>(
                builder: (context, provider, child) {
                  if (provider.items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_outline, size: 80, color: AppColors.textTertiary),
                          const SizedBox(height: 16),
                          Text('Wishlist Kosong / Wishlist Empty', style: AppTextStyles.titleMedium),
                          const SizedBox(height: 8),
                          Text('Simpan produk favoritmu / Save your favorite products', style: AppTextStyles.bodySmall),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: provider.items.length,
                    itemBuilder: (context, index) {
                      final product = provider.items[index];
                      return ProductCard(
                        product: product,
                        isWishlisted: true,
                        onTap: () {
                          Navigator.pushNamed(context, AppRouter.productDetail, arguments: product);
                        },
                        onWishlistTap: () {
                          provider.toggleWishlist(product);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
