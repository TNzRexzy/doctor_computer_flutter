import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/wishlist_provider.dart';
import 'package:doctor_computer/widgets/catalog/filter_bottom_sheet.dart';
import 'package:doctor_computer/widgets/catalog/sort_chips.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
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
  bool _isGridView = true;

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
                      widget.categoryId ?? 'Semua Produk',
                      style: AppTextStyles.heading3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.grid_view, color: _isGridView ? AppColors.primary : AppColors.textTertiary),
                        onPressed: () => setState(() => _isGridView = true),
                      ),
                      IconButton(
                        icon: Icon(Icons.view_list, color: !_isGridView ? AppColors.primary : AppColors.textTertiary),
                        onPressed: () => setState(() => _isGridView = false),
                      ),
                    ],
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
                        'Produk tidak ditemukan',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  if (_isGridView) {
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
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _buildListItem(
                        product,
                        wishlistProvider.isInWishlist(product.id),
                        () => wishlistProvider.toggleWishlist(product),
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

  Widget _buildListItem(ProductModel product, bool isWishlisted, VoidCallback onWishlistTap) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => Navigator.pushNamed(context, AppRouter.productDetail, arguments: product),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: product.images.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(product.images.first, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(Icons.computer, color: AppColors.primary)),
                  )
                : Icon(Icons.computer, color: AppColors.primary, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppTextStyles.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(product.brand, style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: AppColors.warning),
                    Text(' ${product.rating}', style: AppTextStyles.caption),
                    Text(' (${product.reviewCount})', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 4),
                Text(formatRupiah(product.price), style: AppTextStyles.priceSmall),
                if (product.originalPrice != null)
                  Text(formatRupiah(product.originalPrice!), style: AppTextStyles.priceOriginal),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isWishlisted ? Icons.favorite : Icons.favorite_border,
              color: isWishlisted ? AppColors.error : AppColors.textTertiary,
            ),
            onPressed: onWishlistTap,
          ),
        ],
      ),
    );
  }
}

