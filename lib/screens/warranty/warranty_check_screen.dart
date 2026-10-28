import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/ai_chat/doctor_ai_floating.dart';
import 'package:doctor_computer/widgets/common/app_toast.dart';

class WarrantyCheckScreen extends StatefulWidget {
  final String? initialSerial;

  const WarrantyCheckScreen({super.key, this.initialSerial});

  @override
  State<WarrantyCheckScreen> createState() => _WarrantyCheckScreenState();
}

class _WarrantyCheckScreenState extends State<WarrantyCheckScreen> {
  final TextEditingController _serialController = TextEditingController();
  OrderModel? _searchedOrder;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSerial != null) {
      _serialController.text = widget.initialSerial!;
      _doSearch();
    }
  }

  void _doSearch() {
    final query = _serialController.text.trim();
    if (query.isEmpty) return;

    final provider = context.read<OrderProvider>();
    final match =
        provider.getOrderBySerial(query) ?? provider.getOrderById(query);

    setState(() {
      _searchedOrder = match;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().orders;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cek Masa Garansi Aktif'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Search Serial Number Card
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
                      Icon(Icons.verified, color: AppColors.primary, size: 28),
                      const SizedBox(width: 10),
                      Text('Cari Nomor Seri', style: AppTextStyles.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan Serial Number produk atau nomor Order ID untuk memverifikasi keaslian dan sisa masa garansi aktif.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serialController,
                          decoration: InputDecoration(
                            hintText: 'Contoh: SN-TUF-2026-98124',
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _doSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onPressed: _doSearch,
                        child: const Text(
                          'Cek',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_hasSearched) ...[
              const SizedBox(height: 20),
              Text(
                'Hasil Pengecekan Garansi:',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 10),
              if (_searchedOrder != null)
                _buildWarrantyCard(_searchedOrder!)
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nomor Seri "${_serialController.text}" tidak ditemukan di database resmi. Pastikan nomor telah benar.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 24),
            Text(
              'Daftar Produk & Garansi Anda:',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 12),

            ...orders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildWarrantyCard(order),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarrantyCard(OrderModel order) {
    final isActive = order.isWarrantyActive;
    final remainingDays = order.remainingWarrantyDays;
    final firstItem = order.items.isNotEmpty ? order.items.first.product : null;
    final expiry = order.warrantyExpiryDate;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? AppColors.success : AppColors.error,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: isActive ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? 'GARANSI AKTIF' : 'GARANSI HABIS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${order.warrantyDurationMonths} Bulan Garansi Resmi',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            firstItem?.name ?? 'Perangkat Komputer / Komponen PC',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Serial Number',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        order.serialNumber,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Salin serial number',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: order.serialNumber),
                    );
                    if (!mounted) return;
                    AppToast.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Serial number disalin'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tanggal Pembelian',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    '${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Berlaku Hingga',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    '${expiry.day}/${expiry.month}/${expiry.year}',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sisa Masa Garansi:', style: AppTextStyles.caption),
                Text(
                  isActive ? '$remainingDays hari lagi' : 'Telah berakhir',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                  ),
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('Klaim Garansi'),
                  onPressed: () {
                    DoctorAiController.instance.open();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
