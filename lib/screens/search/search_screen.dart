import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/widgets/home/category_grid.dart';

/// Search Screen
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onSearchChanged() {
    context.read<ProductProvider>().setSearchQuery(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProductProvider>().setSearchQuery('');
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Cari produk... / Search products...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _focusNode.unfocus();
                    },
                    child: Text('Cari / Search', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<ProductProvider>(
                builder: (context, provider, child) {
                  if (_searchController.text.isEmpty) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pencarian Terbaru / Recent Searches', style: AppTextStyles.titleSmall),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              'Laptop Gaming', 'RTX 4070', 'Mechanical Keyboard', 'Mouse Wireless', 'SSD 1TB'
                            ].map((query) => ActionChip(
                                  label: Text(query, style: AppTextStyles.bodySmall),
                                  backgroundColor: AppColors.surface,
                                  side: BorderSide.none,
                                  onPressed: () {
                                    _searchController.text = query;
                                  },
                                ))
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                          Text('Kategori Populer / Popular Categories', style: AppTextStyles.titleSmall),
                          const SizedBox(height: 12),
                          CategoryGrid(
                            categories: provider.categories,
                            onCategoryTap: (category) {
                              Navigator.pushReplacementNamed(context, AppRouter.catalog, arguments: category);
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  final results = provider.filteredProducts;

                  if (results.isEmpty) {
                    return Center(
                      child: Text(
                        'Produk tidak ditemukan / Product not found',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final product = results[index];
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.computer, color: AppColors.primary),
                        ),
                        title: Text(product.name, style: AppTextStyles.bodyMedium),
                        subtitle: Text(
                          '${product.brand} • ${formatRupiah(product.price)}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, AppRouter.productDetail, arguments: product);
                        },
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
