import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/services/gemini_service.dart';
import 'package:doctor_computer/services/product_search.dart';
import 'package:doctor_computer/widgets/home/category_grid.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/app_image_view.dart';

/// Search Screen with AI Smart Search & Keyword Search
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isAiMode = false;
  bool _isAiSearching = false;
  bool _aiHasSearched = false;
  int _aiRequestId = 0;
  String _aiExplanation = '';
  List<ProductModel> _aiRecommendations = [];

  final List<String> _aiPrompts = [
    'PC Gaming budget 10 jutaan',
    'Laptop editing video layar OLED',
    'Komponen pendingin paling dingin',
    'RAM DDR5 kencang buat gaming',
    'SSD NVMe transfer cepat',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onSearchChanged() {
    // Rebuild so the standard results and the clear button follow the text.
    if (mounted) setState(() {});
  }

  void _triggerAiSearch(String query) async {
    _searchController.text = query;
    _focusNode.unfocus();
    setState(() {
      _isAiSearching = true;
    });

    final requestId = ++_aiRequestId;
    final productProvider = context.read<ProductProvider>();
    final result = await GeminiService().searchWithAI(
      query: query,
      catalog: productProvider.allProducts,
      categories: productProvider.categories,
    );

    // Ignore outdated answers when a newer search was started meanwhile.
    if (!mounted || requestId != _aiRequestId) return;
    setState(() {
      _aiExplanation = result['explanation'] as String? ?? '';
      _aiRecommendations = (result['recommendations'] as List).cast<ProductModel>();
      _aiHasSearched = true;
      _isAiSearching = false;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Back
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: _isAiMode
                            ? 'Tanya AI (contoh: PC buat GTA V lancar)...'
                            : 'Cari produk, brand, komponen...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        prefixIcon: Icon(
                          _isAiMode ? Icons.auto_awesome : Icons.search,
                          color: _isAiMode ? AppColors.accent : AppColors.textSecondary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: AppColors.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _aiExplanation = '';
                                    _aiRecommendations = [];
                                    _aiHasSearched = false;
                                    _aiRequestId++;
                                    _isAiSearching = false;
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isAiMode ? AppColors.accent : Colors.transparent,
                          ),
                        ),
                      ),
                      onSubmitted: (val) {
                        if (_isAiMode && val.isNotEmpty) {
                          _triggerAiSearch(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _focusNode.unfocus();
                      if (_isAiMode && _searchController.text.isNotEmpty) {
                        _triggerAiSearch(_searchController.text);
                      }
                    },
                    child: Text('Cari', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
                  ),
                ],
              ),
            ),

            // Toggle AI Mode Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isAiMode = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isAiMode ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Pencarian Standar',
                              style: TextStyle(
                                color: !_isAiMode ? Colors.white : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isAiMode = true;
                          });
                          if (_searchController.text.isNotEmpty) {
                            _triggerAiSearch(_searchController.text);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isAiMode ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: _isAiMode ? Colors.black87 : AppColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '✨ AI Smart Search',
                                style: TextStyle(
                                  color: _isAiMode ? Colors.black87 : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Body Content
            Expanded(
              child: _isAiMode ? _buildAiView() : _buildStandardView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiView() {
    if (_isAiSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              'Gemini AI sedang menganalisis kebutuhan Anda...',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_aiRecommendations.isEmpty && !_aiHasSearched) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.accent, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pencarian Pintar Berbasis Gemini AI', style: AppTextStyles.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Ketik kebutuhan Anda secara bebas, misal budget, software yang dipakai, atau game yang ingin dimainkan.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Inspirasi Pertanyaan ke AI:', style: AppTextStyles.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _aiPrompts.map((prompt) {
                return ActionChip(
                  avatar: Icon(Icons.psychology, size: 16, color: AppColors.primary),
                  label: Text(prompt, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  onPressed: () => _triggerAiSearch(prompt),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_aiExplanation.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.smart_toy, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _aiExplanation,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        if (_aiRecommendations.isNotEmpty) ...[
          Text('Rekomendasi Komponen & Produk AI (${_aiRecommendations.length}):', style: AppTextStyles.titleSmall),
          const SizedBox(height: 12),
        ],
        ..._aiRecommendations.map((product) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              onTap: () {
                Navigator.pushNamed(context, AppRouter.productDetail, arguments: product);
              },
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AppImageView(
                      imageUrl: product.images.isNotEmpty ? product.images.first : product.id,
                      width: 60,
                      height: 60,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: AppTextStyles.titleSmall),
                        Text(product.brand, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(formatRupiah(product.price), style: AppTextStyles.priceSmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStandardView() {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (_searchController.text.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pencarian Populer', style: AppTextStyles.titleSmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Laptop Gaming', 'RTX 4080', 'RAM DDR5', 'SSD Samsung', 'Intel i7', 'MSI Motherboard'
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
                Text('Kategori Produk', style: AppTextStyles.titleSmall),
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

        final results = ProductSearch.search(
          _searchController.text,
          provider.allProducts,
          categories: provider.categories,
        ).products;

        if (results.isEmpty) {
          return Center(
            child: Text(
              'Produk tidak ditemukan',
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
                child: AppImageView(
                  imageUrl: product.images.isNotEmpty ? product.images.first : product.id,
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(8),
                ),
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
    );
  }
}