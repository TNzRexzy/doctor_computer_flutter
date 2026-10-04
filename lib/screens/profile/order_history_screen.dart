import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/mock/mock_pc_parts.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    List<OrderModel> filteredOrders = mockOrders;
    if (_selectedTab == 1) {
      filteredOrders = mockOrders.where((o) => o.status == OrderStatus.processing).toList();
    } else if (_selectedTab == 2) {
      filteredOrders = mockOrders.where((o) => o.status == OrderStatus.shipped).toList();
    } else if (_selectedTab == 3) {
      filteredOrders = mockOrders.where((o) => o.status == OrderStatus.delivered).toList();
    }

    return Scaffold(
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
                  Text('Pesanan Saya / My Orders', style: AppTextStyles.heading3),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildTab(0, 'Semua/All'),
                  _buildTab(1, 'Diproses/Processing'),
                  _buildTab(2, 'Dikirim/Shipped'),
                  _buildTab(3, 'Selesai/Delivered'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 16.0),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return GlassCard(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Order #${order.id}', style: AppTextStyles.titleSmall),
                            const Spacer(),
                            Chip(
                              label: Text(order.status.displayNameId),
                              backgroundColor: order.status.color.withOpacity(0.2),
                              labelStyle: TextStyle(color: order.status.color),
                              side: BorderSide.none,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${order.items.length} items', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year}'),
                            const Spacer(),
                            Text(formatRupiah(order.totalPrice), style: AppTextStyles.priceSmall),
                          ],
                        ),
                        if (order.status == OrderStatus.delivered) ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () {},
                            child: const Text('Beri Ulasan / Review'),
                          )
                        ]
                      ],
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

