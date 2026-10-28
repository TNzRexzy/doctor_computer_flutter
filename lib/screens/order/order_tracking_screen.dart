import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/app_toast.dart';

class OrderTrackingScreen extends StatelessWidget {
  final OrderModel order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {
        'title': 'Pesanan Diterima & Terverifikasi',
        'subtitle': 'Pembayaran berhasil dikonfirmasi oleh sistem keuangan.',
        'time':
            '${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year} 10:15 WIB',
        'isCompleted': true,
      },
      {
        'title': 'Pengecekan Komponen & Quality Control',
        'subtitle':
            'Pemeriksaan fisik komponen, segel distributor, dan kelengkapan.',
        'time':
            '${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year} 11:30 WIB',
        'isCompleted': true,
      },
      {
        'title': 'Pengemasan Ekstra Aman (Packing Kayu + Bubble)',
        'subtitle': 'Kemasan telah disegel dengan stiker Fragile dan siap diambil kurir.',
        'time':
            '${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year} 14:00 WIB',
        'isCompleted': order.status != OrderStatus.processing,
      },
      {
        'title': 'Diserahkan ke Kurir Ekspedisi',
        'subtitle':
            '${order.courier} telah mengambil paket dari gudang Doctor Computer.',
        'time':
            '${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year} 16:45 WIB',
        'isCompleted':
            order.status == OrderStatus.shipped ||
            order.status == OrderStatus.delivered,
      },
      {
        'title': 'Dalam Perjalanan Menuju Alamat Penerima',
        'subtitle': 'Paket sedang diantar ke ${order.shippingAddress}',
        'time': order.status == OrderStatus.delivered
            ? 'Tiba di Hub Kota Tujuan'
            : 'Dalam proses transit',
        'isCompleted': order.status == OrderStatus.delivered,
      },
      {
        'title': 'Pesanan Selesai',
        'subtitle': 'Paket telah diterima dengan baik di alamat tujuan.',
        'time': order.status == OrderStatus.delivered
            ? 'Terkirim'
            : 'Estimasi: 1-2 hari kerja',
        'isCompleted': order.status == OrderStatus.delivered,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pelacakan Pesanan #${order.displayId}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Courier & Resi Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_shipping,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.courier,
                              style: AppTextStyles.titleSmall,
                            ),
                            Text(
                              'Status: ${order.status.displayNameId}',
                              style: AppTextStyles.caption.copyWith(
                                color: order.status.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nomor Resi:',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.trackingNumber.trim().isEmpty
                                ? 'Belum tersedia'
                                : order.trackingNumber,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: order.trackingNumber.trim().isEmpty
                                  ? AppColors.textTertiary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Salin Resi'),
                        onPressed: order.trackingNumber.trim().isEmpty
                            ? null
                            : () {
                                Clipboard.setData(
                                  ClipboardData(text: order.trackingNumber),
                                );
                                AppToast.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Nomor resi berhasil disalin!',
                                    ),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Status Perjalanan Paket', style: AppTextStyles.titleMedium),
            const SizedBox(height: 16),

            // Timeline Steps
            ...List.generate(steps.length, (index) {
              final step = steps[index];
              final isCompleted = step['isCompleted'] as bool;
              final isLast = index == steps.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? AppColors.success
                                : AppColors.surface,
                            border: Border.all(
                              color: isCompleted
                                  ? AppColors.success
                                  : AppColors.textTertiary,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.textTertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isCompleted
                                  ? AppColors.success
                                  : AppColors.border,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      step['title'] as String,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: isCompleted
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isCompleted
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    step['time'] as String,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                step['subtitle'] as String,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            // Order details summary
            Text('Ringkasan Barang', style: AppTextStyles.titleMedium),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...order.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.product.name} (x${item.quantity})',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                          Text(
                            formatRupiah(item.subtotal),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Nilai Pesanan:',
                        style: AppTextStyles.titleSmall,
                      ),
                      Text(
                        formatRupiah(order.totalPrice),
                        style: AppTextStyles.priceSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
