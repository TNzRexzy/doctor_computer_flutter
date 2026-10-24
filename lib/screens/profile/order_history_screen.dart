import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/app_image_view.dart';
import 'package:doctor_computer/providers/review_provider.dart';
import 'package:doctor_computer/data/models/review_model.dart';
import 'package:doctor_computer/screens/order/order_tracking_screen.dart';
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

  void _showRatingDialog(
    BuildContext context,
    OrderModel order, {
    bool isEditing = false,
  }) {
    double selectedRating = order.rating ?? 5.0;
    final commentController = TextEditingController(
      text: order.reviewComment ?? '',
    );
    final List<String> mediaList = List<String>.from(order.reviewMediaUrls);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Row(
              children: [
                Icon(isEditing ? Icons.edit : Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Ubah Rating Pesanan' : 'Beri Rating Pesanan',
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pesanan #${order.id}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isEditing)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Informasi: Anda memiliki sisa ${order.remainingEditDays} hari untuk mengubah rating pesanan ini (Maksimal 7 hari setelah rating awal).',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1.0;
                        return IconButton(
                          icon: Icon(
                            star <= selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              selectedRating = star;
                            });
                          },
                        );
                      }),
                    ),
                  ),
                  Center(
                    child: Text(
                      '$selectedRating dari 5.0 Bintang',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ulasan & Pengalaman Belanja:',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Tuliskan ulasan mengenai produk, kemasan, atau pelayanan...',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Lampiran Gambar atau Video:',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (mediaList.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: mediaList.map((media) {
                        final isVideo =
                            media.contains('.mp4') ||
                            media.contains('.mov') ||
                            media.contains('.webm') ||
                            media.contains('video') ||
                            media.contains('youtu');
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AppImageView(
                                      imageUrl: media,
                                      fit: BoxFit.cover,
                                      width: 60,
                                      height: 60,
                                    ),
                                    if (isVideo)
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    mediaList.remove(media);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_photo_alternate, size: 16),
                        label: const Text(
                          'Foto (JPG/PNG)',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () {
                          final inputC = TextEditingController();
                          showDialog(
                            context: context,
                            builder: (addCtx) => AlertDialog(
                              title: const Text('Tambah Lampiran Foto'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Masukkan URL foto atau path file (JPG, PNG, WEBP):',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: inputC,
                                    decoration: const InputDecoration(
                                      hintText: 'https://.../foto.jpg',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      ActionChip(
                                        label: const Text(
                                          'Foto Produk 1',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        onPressed: () => inputC.text = 'assets/images/products/tuf_f15.png',
                                      ),
                                      ActionChip(
                                        label: const Text(
                                          'Foto Unboxing',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        onPressed: () => inputC.text = 'assets/images/products/rog_strix_g16.png',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(addCtx),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final val = inputC.text.trim();
                                    if (val.isNotEmpty) {
                                      setDialogState(() {
                                        mediaList.add(val);
                                      });
                                    }
                                    Navigator.pop(addCtx);
                                  },
                                  child: const Text('Tambah'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.videocam, size: 16),
                        label: const Text(
                          'Video',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () {
                          final inputC = TextEditingController();
                          showDialog(
                            context: context,
                            builder: (addCtx) => AlertDialog(
                              title: const Text('Tambah Lampiran Video'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Masukkan tautan video review (MP4, WebM, YouTube):',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: inputC,
                                    decoration: const InputDecoration(
                                      hintText: 'https://.../review.mp4',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(addCtx),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final val = inputC.text.trim();
                                    if (val.isNotEmpty) {
                                      setDialogState(() {
                                        mediaList.add(val);
                                      });
                                    }
                                    Navigator.pop(addCtx);
                                  },
                                  child: const Text('Tambah'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () async {
                  final success = await context
                      .read<OrderProvider>()
                      .updateOrderRating(
                        order.id,
                        selectedRating,
                        commentController.text.trim(),
                        mediaUrls: mediaList,
                      );
                  if (!ctx.mounted) return;

                  if (success) {
                    final reviewProvider = context.read<ReviewProvider>();
                    final authUser = context.read<AuthProvider>().currentUser;
                    final authorName =
                        authUser?.fullName ?? 'Pelanggan Doctor Computer';
                    final authorId = authUser?.id ?? 'user';

                    for (final item in order.items) {
                      final rModel = ReviewModel(
                        id: 'rev-${order.id}-${item.product.id}',
                        userId: authorId,
                        userName: authorName,
                        productId: item.product.id,
                        rating: selectedRating,
                        comment: commentController.text.trim(),
                        date: DateTime.now(),
                        mediaUrls: mediaList,
                      );
                      reviewProvider.addReview(rModel);
                    }

                    Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text(
                          context.read<OrderProvider>().errorMessage ??
                              'Rating tidak dapat disimpan.',
                        ),
                      ),
                    );
                    return;
                  }
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text(
                          isEditing
                              ? 'Rating berhasil diperbarui!'
                              : 'Terima kasih atas ulasan & rating Anda!',
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  isEditing ? 'Simpan Perubahan' : 'Kirim Rating',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Pesanan #${order.id}',
                                      style: AppTextStyles.titleSmall,
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

                                // Rating Section for Delivered Orders
                                if (order.status == OrderStatus.delivered) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.border.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (order.hasRating) ...[
                                          Row(
                                            children: [
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (i) => Icon(
                                                    i < order.rating!.toInt()
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${order.rating} / 5.0',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.amber,
                                                    ),
                                              ),
                                              const Spacer(),
                                              if (order.canEditRating)
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    size: 14,
                                                  ),
                                                  label: Text(
                                                    'Ubah Rating (${order.remainingEditDays} hari lagi)',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      _showRatingDialog(
                                                        context,
                                                        order,
                                                        isEditing: true,
                                                      ),
                                                )
                                              else
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.lock,
                                                      size: 12,
                                                      color: AppColors
                                                          .textTertiary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Rating Terkunci (>7 hari)',
                                                      style: AppTextStyles
                                                          .caption
                                                          .copyWith(
                                                            color: AppColors
                                                                .textTertiary,
                                                            fontSize: 10,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                          if (order.reviewComment != null &&
                                              order
                                                  .reviewComment!
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '"${order.reviewComment}"',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                            ),
                                          ],
                                          if (order
                                              .reviewMediaUrls
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              children: order.reviewMediaUrls.map(
                                                (m) {
                                                  return Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: AppColors.border,
                                                      ),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      child: AppImageView(
                                                        imageUrl: m,
                                                        fit: BoxFit.cover,
                                                        width: 44,
                                                        height: 44,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ).toList(),
                                            ),
                                          ],
                                        ] else ...[
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Belum memberikan ulasan pesanan',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.amber,
                                                  foregroundColor:
                                                      Colors.black87,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                ),
                                                icon: const Icon(
                                                  Icons.star,
                                                  size: 14,
                                                ),
                                                label: const Text(
                                                  'Beri Rating',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _showRatingDialog(
                                                      context,
                                                      order,
                                                      isEditing: false,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
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
