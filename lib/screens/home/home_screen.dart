import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/wishlist_provider.dart';
import 'package:doctor_computer/widgets/home/promo_banner_carousel.dart';
import 'package:doctor_computer/widgets/home/category_grid.dart';
import 'package:doctor_computer/widgets/home/flash_deal_timer.dart';
import 'package:doctor_computer/widgets/home/product_card.dart';
import 'package:doctor_computer/widgets/common/badge_icon.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/providers/notification_provider.dart';
import 'package:doctor_computer/screens/notifications/notifications_screen.dart';
import 'package:doctor_computer/screens/ai_chat/ai_customer_service_screen.dart';
import 'package:doctor_computer/screens/member/member_screen.dart';
import 'package:doctor_computer/screens/warranty/warranty_check_screen.dart';
import 'package:doctor_computer/screens/main_nav_screen.dart';

/// Home Screen
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final user = context.watch<AuthProvider>().currentUser;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Halo, ${user?.fullName ?? ""}',
                            style: AppTextStyles.titleMedium,
                          ),
                          Text(
                            'Selamat datang di Doctor Computer',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Consumer<NotificationProvider>(
                      builder: (context, notifProvider, child) {
                        return IconButton(
                          icon: BadgeIcon(
                            icon: Icons.notifications_none,
                            count: notifProvider.unreadCount,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            );
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.search, color: AppColors.textPrimary),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRouter.search);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRouter.search),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Cari produk...',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PromoBannerCarousel(),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MemberScreen()));
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.sports_esports, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Minigames & EXP', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyCheckScreen()));
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified, color: AppColors.accent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Cek Garansi', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kategori', style: AppTextStyles.titleMedium),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRouter.catalog),
                      child: Text('Lihat Semua', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              Consumer<ProductProvider>(
                builder: (context, provider, child) {
                  return CategoryGrid(
                    categories: provider.categories,
                    onCategoryTap: (category) {
                      Navigator.pushNamed(context, AppRouter.catalog, arguments: category);
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('Flash Sale', style: AppTextStyles.titleMedium),
                    const SizedBox(width: 8),
                    const FlashDealTimer(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Consumer2<ProductProvider, WishlistProvider>(
                builder: (context, productProvider, wishlistProvider, child) {
                  final deals = productProvider.flashDeals;
                  return SizedBox(
                    height: 280,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: deals.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final product = deals[index];
                        return SizedBox(
                          width: 160,
                          child: ProductCard(
                            product: product,
                            onTap: () => Navigator.pushNamed(context, AppRouter.productDetail, arguments: product),
                            onWishlistTap: () => wishlistProvider.toggleWishlist(product),
                            isWishlisted: wishlistProvider.isInWishlist(product.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Produk Terlaris', style: AppTextStyles.titleMedium),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRouter.catalog),
                      child: Text('Lihat Semua', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              Consumer2<ProductProvider, WishlistProvider>(
                builder: (context, productProvider, wishlistProvider, child) {
                  final bestSellers = productProvider.bestSellers;
                  return SizedBox(
                    height: 280,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: bestSellers.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final product = bestSellers[index];
                        return SizedBox(
                          width: 160,
                          child: ProductCard(
                            product: product,
                            onTap: () => Navigator.pushNamed(context, AppRouter.productDetail, arguments: product),
                            onWishlistTap: () => wishlistProvider.toggleWishlist(product),
                            isWishlisted: wishlistProvider.isInWishlist(product.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Baru Datang', style: AppTextStyles.titleMedium),
              ),
              const SizedBox(height: 12),
              Consumer2<ProductProvider, WishlistProvider>(
                builder: (context, productProvider, wishlistProvider, child) {
                  final newArrivals = productProvider.newArrivals.take(6).toList();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: newArrivals.length,
                      itemBuilder: (context, index) {
                        final product = newArrivals[index];
                        return ProductCard(
                          product: product,
                          onTap: () => Navigator.pushNamed(context, AppRouter.productDetail, arguments: product),
                          onWishlistTap: () => wishlistProvider.toggleWishlist(product),
                          isWishlisted: wishlistProvider.isInWishlist(product.id),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () {
                    // Switch to PC Builder tab in MainNavScreen instead of pushing new route
                    final mainNavState = context.findAncestorStateOfType<MainNavScreenState>();
                    if (mainNavState != null) {
                      mainNavState.switchToTab(2);
                    } else {
                      Navigator.pushNamed(context, AppRouter.pcBuilder);
                    }
                  },
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.accent.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Rakit PC Impianmu', style: AppTextStyles.titleMedium),
                                  const SizedBox(height: 4),
                                  Text('Konfigurator interaktif', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Icon(Icons.build_circle, size: 48, color: AppColors.accent),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 75.0 + MediaQuery.of(context).padding.bottom),
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.smart_toy, color: Colors.white),
          label: const Text('Tanya Dokter AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiCustomerServiceScreen()),
            );
          },
        ),
      ),
    );
  }
}

