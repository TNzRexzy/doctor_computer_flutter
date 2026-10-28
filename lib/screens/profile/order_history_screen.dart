import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/app_image_view.dart';
import 'package:doctor_computer/providers/review_provider.dart';
import 'package:doctor_computer/data/models/review_model.dart';
import 'package:doctor_computer/screens/order/order_tracking_screen.dart';
import 'package:doctor_computer/screens/profile/product_review_screen.dart';
import 'package:doctor_computer/services/review_media_service.dart';
import 'package:doctor_computer/widgets/review/review_media_viewer.dart';
import 'package:doctor_computer/screens/warranty/warranty_check_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<OrderProvider>().setUserId(user.id);
      }
    });
  }

  Future<void> _openReviewForm(
    OrderModel order,
    CartItemModel item,
    ReviewModel? existing,
  ) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductReviewScreen(order: order, item: item, existing: existing),
      ),
    );
  }

  /// Ulasan per item untuk pesanan yang sudah selesai.
  Widget _buildItemReviewSection(OrderModel order) {
    final reviewProvider = context.watch<ReviewProvider>();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ulasan Produk',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...order.items.map((item) {
            final review = reviewProvider.reviewForOrderItem(
              order.id,
              item.product.id,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AppImageView(
                          imageUrl: item.product.images.isNotEmpty
                              ? item.product.images.first
                              : null,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: AppTextStyles.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (review == null)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                          ),
                          icon: const Icon(Icons.star, size: 14),
                          label: const Text(
                            'Beri Ulasan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _openReviewForm(order, item, null),
                        )
                      else if (review.canEdit)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.edit, size: 14),
                          label: Text(
                            'Ubah (${review.remainingEditDays} hari)',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () => _openReviewForm(order, item, review),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 12,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Terkunci',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (review != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${review.rating.toStringAsFixed(1)} / 5.0',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    if (review.comment.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '"${review.comment}"',
                        style: AppTextStyles.caption.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (review.mediaUrls.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(review.mediaUrls.length, (i) {
                          final url = review.mediaUrls[i];
                          final isVideo = ReviewMediaService.isVideoUrl(url);
                          return GestureDetector(
                            onTap: () => showReviewMediaViewer(
                              context,
                              review.mediaUrls,
                              i,
                            ),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isVideo ? Colors.black : null,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: isVideo
                                    ? const Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white,
                                        size: 22,
                                      )
                                    : AppImageView(
                                        imageUrl: url,
                                        fit: BoxFit.cover,
                                        width: 44,
                                        height: 44,
                                      ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final allOrders = orderProvider.orders;

    List<OrderModel> filteredOrders = allOrders;
    if (_selectedTab == 1) {
      filteredOrders = allOrders
          .where((o) => o.status == OrderStatus.processing)
          .toList();
    } else if (_selectedTab == 2) {
      filteredOrders = allOrders
          .where((o) => o.status == OrderStatus.shipped)
          .toList();
    } else if (_selectedTab == 3) {
      filteredOrders = allOrders
          .where((o) => o.status == OrderStatus.delivered)
          .toList();
    }

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
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text('Pesanan Saya', style: AppTextStyles.heading3),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.verified, color: AppColors.primary),
                    tooltip: 'Cek Garansi',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WarrantyCheckScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildTab(0, 'Semua (${allOrders.length})'),
                  _buildTab(1, 'Diproses'),
                  _buildTab(2, 'Dikirim'),
                  _buildTab(3, 'Selesai'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada pesanan pada status ini',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OrderTrackingScreen(order: order),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Pesanan #${order.displayId}',
                                      style: AppTextStyles.titleSmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Chip(
                                      label: Text(order.status.displayNameId),
                                      backgroundColor: order.status.color
                                          .withValues(alpha: 0.15),
                                      labelStyle: TextStyle(
                                        color: order.status.color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                      side: BorderSide.none,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...order.items.map(
                                  (it) => Text(
                                    '• ${it.product.name} (x${it.quantity})',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year}',
                                      style: AppTextStyles.caption,
                                    ),
                                    const Spacer(),
                                    Text(
                                      formatRupiah(order.totalPrice),
                                      style: AppTextStyles.priceSmall,
                                    ),
                                  ],
                                ),

                                const Divider(height: 18),

                                // Action Buttons (Cek Status Pesanan, Cek Garansi, Rating)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        side: BorderSide(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.track_changes,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Cek Status Pesanan',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OrderTrackingScreen(
                                              order: order,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        side: BorderSide(
                                          color: AppColors.accent,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.shield_outlined,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Cek Garansi',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => WarrantyCheckScreen(
                                              initialSerial: order.serialNumber,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),

                                // Ulasan per item untuk pesanan selesai
                                if (order.status == OrderStatus.delivered) ...[
                                  const SizedBox(height: 10),
                                  _buildItemReviewSection(order),
                                ],
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

  Widget _buildTab(int index, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedTab == index,
        onSelected: (val) {
          if (val) setState(() => _selectedTab = index);
        },
      ),
    );
  }
}
