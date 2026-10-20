import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
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

  void _showRatingDialog(BuildContext context, OrderModel order, {bool isEditing = false}) {
    double selectedRating = order.rating ?? 5.0;
    final commentController = TextEditingController(text: order.reviewComment ?? '');

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
                Text(isEditing ? 'Ubah Rating Pesanan' : 'Beri Rating Pesanan', style: AppTextStyles.titleMedium),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pesanan #${order.id}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  if (isEditing)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '💡 Anda memiliki sisa ${order.remainingEditDays} hari untuk mengubah rating pesanan ini (Maksimal 7 hari setelah rating awal).',
                        style: AppTextStyles.caption.copyWith(color: AppColors.warning),
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
                            star <= selectedRating ? Icons.star : Icons.star_border,
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
                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Ulasan & Pengalaman Belanja:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Tuliskan ulasan mengenai produk, kemasan, atau pelayanan...',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
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
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  final success = context.read<OrderProvider>().updateOrderRating(
                    order.id,
                    selectedRating,
                    commentController.text.trim(),
                  );
                  Navigator.pop(ctx);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text(isEditing ? 'Rating berhasil diperbarui!' : 'Terima kasih atas rating Anda!'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('Batas waktu pengubahan rating (7 hari) telah berakhir.'),
                      ),
                    );
                  }
                },
                child: Text(isEditing ? 'Simpan Perubahan' : 'Kirim Rating', style: const TextStyle(color: Colors.white)),
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
      filteredOrders = allOrders.where((o) => o.status == OrderStatus.processing).toList();
    } else if (_selectedTab == 2) {
      filteredOrders = allOrders.where((o) => o.status == OrderStatus.shipped).toList();
    } else if (_selectedTab == 3) {
      filteredOrders = allOrders.where((o) => o.status == OrderStatus.delivered).toList();
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
                        MaterialPageRoute(builder: (_) => const WarrantyCheckScreen()),
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
                      child: Text('Tidak ada pesanan pada status ini', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                                    Text('Pesanan #${order.id}', style: AppTextStyles.titleSmall),
                                    const Spacer(),
                                    Chip(
                                      label: Text(order.status.displayNameId),
                                      backgroundColor: order.status.color.withValues(alpha: 0.15),
                                      labelStyle: TextStyle(color: order.status.color, fontWeight: FontWeight.bold, fontSize: 11),
                                      side: BorderSide.none,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...order.items.map((it) => Text(
                                  '• ${it.product.name} (x${it.quantity})',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                )),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year}', style: AppTextStyles.caption),
                                    const Spacer(),
                                    Text(formatRupiah(order.totalPrice), style: AppTextStyles.priceSmall),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        side: BorderSide(color: AppColors.primary),
                                      ),
                                      icon: const Icon(Icons.track_changes, size: 16),
                                      label: const Text('Cek Status Pesanan', style: TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order)),
                                        );
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        side: BorderSide(color: AppColors.accent),
                                      ),
                                      icon: const Icon(Icons.shield_outlined, size: 16),
                                      label: const Text('Cek Garansi', style: TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => WarrantyCheckScreen(initialSerial: order.serialNumber)),
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
                                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (order.hasRating) ...[
                                          Row(
                                            children: [
                                              Row(
                                                children: List.generate(5, (i) => Icon(
                                                  i < order.rating!.toInt() ? Icons.star : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 16,
                                                )),
                                              ),
                                              const SizedBox(width: 6),
                                              Text('${order.rating} / 5.0', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.amber)),
                                              const Spacer(),
                                              if (order.canEditRating)
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                                  icon: const Icon(Icons.edit, size: 14),
                                                  label: Text('Ubah Rating (${order.remainingEditDays} hari lagi)', style: const TextStyle(fontSize: 11)),
                                                  onPressed: () => _showRatingDialog(context, order, isEditing: true),
                                                )
                                              else
                                                Row(
                                                  children: [
                                                    Icon(Icons.lock, size: 12, color: AppColors.textTertiary),
                                                    const SizedBox(width: 4),
                                                    Text('Rating Terkunci (>7 hari)', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 10)),
                                                  ],
                                                ),
                                            ],
                                          ),
                                          if (order.reviewComment != null && order.reviewComment!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text('"${order.reviewComment}"', style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
                                          ],
                                        ] else ...[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Belum memberikan ulasan pesanan', style: TextStyle(fontSize: 12)),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.amber,
                                                  foregroundColor: Colors.black87,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                ),
                                                icon: const Icon(Icons.star, size: 14),
                                                label: const Text('Beri Rating', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                onPressed: () => _showRatingDialog(context, order, isEditing: false),
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
