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

/// Home Screen with Pinned Sticky Search Bar and Draggable Floating Doctor AI Button
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Offset? _fabPosition;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final user = context.watch<AuthProvider>().currentUser;
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Initialize default floating position at bottom right if not set
    _fabPosition ??= Offset(
      size.width - 170.0,
      size.height - 180.0 - bottomPadding,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Main Column containing Sticky Top Search Bar and Scrollable Body
            Column(
              children: [
                // ============================================================
                // STICKY TOP SECTION: Greeting, Notif Icon, and Fixed Search Bar
                // This section stays pinned on top when user scrolls down
                // ============================================================
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.96),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, ${user?.fullName ?? ""}',
                                  style: AppTextStyles.titleMedium,
                                  overflow: TextOverflow.ellipsis,
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
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Sticky Persistent Search Box
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRouter.search),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: AppColors.primary, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Cari produk komputer, laptop, sparepart...',
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.tune, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Filter',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ============================================================
                // SCROLLABLE CONTENT
                // ============================================================
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
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
                        Consumer<ProductProvider>(
                          builder: (context, pp, _) => pp.flashDeals.isEmpty
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Row(
                                    children: [
                                      Text('Flash Sale', style: AppTextStyles.titleMedium),
                                      const SizedBox(width: 8),
                                      const FlashDealTimer(),
                                    ],
                                  ),
                                ),
                        ),
                        Consumer2<ProductProvider, WishlistProvider>(
                          builder: (context, productProvider, wishlistProvider, child) {
                            final deals = productProvider.flashDeals;
                            if (deals.isEmpty) {
                              return const SizedBox.shrink();
                            }
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
                            if (bestSellers.isEmpty) {
                              return const SizedBox.shrink();
                            }
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
                            final screenWidth = MediaQuery.of(context).size.width;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2),
                                  childAspectRatio: screenWidth > 600 ? 0.65 : (screenWidth < 360 ? 0.52 : 0.56),
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
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ============================================================
            // FLOATING DRAGGABLE DOCTOR AI CUSTOMER SERVICE BUTTON
            // User can freely drag and reposition this button anywhere
            // ============================================================
            Positioned(
              left: _fabPosition!.dx,
              top: _fabPosition!.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    double newX = _fabPosition!.dx + details.delta.dx;
                    double newY = _fabPosition!.dy + details.delta.dy;

                    // Clamping within screen bounds
                    newX = newX.clamp(12.0, size.width - 165.0);
                    newY = newY.clamp(topPadding + 70.0, size.height - 110.0 - bottomPadding);

                    _fabPosition = Offset(newX, newY);
                  });
                },
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiCustomerServiceScreen()),
                  );
                },
                child: Material(
                  elevation: 10,
                  shadowColor: AppColors.primary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.drag_indicator, size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        const Icon(Icons.smart_toy, color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        const Text(
                          'Tanya Dokter AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
