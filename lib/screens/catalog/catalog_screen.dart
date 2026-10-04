import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/wishlist_provider.dart';
import 'package:doctor_computer/widgets/catalog/filter_bottom_sheet.dart';
import 'package:doctor_computer/widgets/catalog/sort_chips.dart';
import 'package:doctor_computer/widgets/home/category_grid.dart';
import 'package:doctor_computer/widgets/home/product_card.dart';

/// Catalog Screen
class CatalogScreen extends StatefulWidget {
  final String? categoryId;

  const CatalogScreen({super.key, this.categoryId});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.categoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ProductProvider>().setCategory(widget.categoryId!);
      });
    }
  }

  @override
  void dispose() {
    if (widget.categoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ProductProvider>().clearFilters();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (widget.categoryId != null)
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  Expanded(
                    child: Text(
                      widget.categoryId ?? 'Semua Produk / All Products',
                      style: AppTextStyles.heading3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.filter_list, color: AppColors.textPrimary),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => FilterBottomSheet(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SortChips(),
            ),
            const SizedBox(height: 8),
            if (widget.categoryId == null)
              Consumer<ProductProvider>(
                builder: (context, provider, child) {
                  return CategoryGrid(
                    categories: provider.categories,
                    onCategoryTap: (category) {
                      provider.setCategory(category);
                    },
                  );
                },
              ),
            Expanded(
              child: Consumer2<ProductProvider, WishlistProvider>(
                builder: (context, productProvider, wishlistProvider, child) {
                  final products = productProvider.filteredProducts;

                  if (products.isEmpty) {
                    return Center(
                      child: Text(
                        'Produk tidak ditemukan / Product not found',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.55,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        product: product,
                        onTap: () => Navigator.pushNamed(context, AppRouter.productDetail, arguments: product),
                        onWishlistTap: () => wishlistProvider.toggleWishlist(product),
                        isWishlisted: wishlistProvider.isInWishlist(product.id),
                      );
                    },
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

