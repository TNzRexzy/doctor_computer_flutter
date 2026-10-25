import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/widgets/common/app_image_view.dart';
import 'package:doctor_computer/navigation/app_router.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Consumer<CartProvider>(
          builder: (context, provider, child) {
            if (provider.items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    Text('Keranjang Kosong', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text('Mulai belanja sekarang', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Text('Keranjang', style: AppTextStyles.heading3),
                      Text(' (${provider.itemCount} items)', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.items.length,
                    itemBuilder: (context, index) {
                      final item = provider.items[index];
                      return Dismissible(
                        key: ValueKey(item.product.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          color: AppColors.error,
                          child: Icon(Icons.delete, color: AppColors.textPrimary),
                        ),
                        onDismissed: (_) {
                          provider.removeFromCart(item.product.id);
                        },
                        child: GlassCard(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AppImageView(
                                    imageUrl: item.product.images.isNotEmpty
                                        ? item.product.images.first
                                        : item.product.id,
                                    fit: BoxFit.cover,
                                    width: 70,
                                    height: 70,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: AppTextStyles.titleSmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(item.product.brand, style: AppTextStyles.caption),
                                    const SizedBox(height: 6),
                                    Text(formatRupiah(item.product.price), style: AppTextStyles.priceSmall),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.remove, size: 18),
                                        onPressed: () {
                                          if (item.quantity > 1) {
                                            provider.updateQuantity(item.product.id, item.quantity - 1);
                                          } else {
                                            provider.removeFromCart(item.product.id);
                                          }
                                        },
                                      ),
                                      Container(
                                        width: 28,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.add, size: 18),
                                        onPressed: item.quantity >= item.product.stock
                                            ? null
                                            : () {
                                                provider.updateQuantity(item.product.id, item.quantity + 1);
                                              },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatRupiah(item.subtotal),
                                    style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: GlassCard(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              const Expanded(
                                child: TextField(
                                  style: TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'Kode Kupon',
                                    prefixIcon: Icon(Icons.local_offer_outlined, size: 20),
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                ),
                                onPressed: () {},
                                child: const Text('Apply', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal', style: AppTextStyles.caption),
                            Text(formatRupiah(provider.totalPrice), style: AppTextStyles.caption),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Estimasi Ongkir', style: AppTextStyles.caption),
                            Text('Rp 15.000', style: AppTextStyles.caption),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total', style: AppTextStyles.caption),
                                  Text(
                                    formatRupiah(provider.totalPrice + 15000),
                                    style: AppTextStyles.price.copyWith(color: AppColors.accent, fontSize: 17),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GradientButton(
                              label: 'Checkout',
                              icon: Icons.payment,
                              height: 44,
                              width: 150,
                              onPressed: () {
                                Navigator.pushNamed(context, AppRouter.checkout);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}
