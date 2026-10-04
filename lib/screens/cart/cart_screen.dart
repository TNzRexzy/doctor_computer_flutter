import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/navigation/app_router.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    Text('Keranjang Kosong / Cart is Empty', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text('Mulai belanja sekarang / Start shopping now', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
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
                      Text('Keranjang / Cart', style: AppTextStyles.heading3),
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
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          provider.removeFromCart(item.product.id);
                        },
                        child: GlassCard(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                          child: Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(child: Icon(Icons.image)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: AppTextStyles.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    Text(item.product.brand, style: AppTextStyles.caption),
                                    const SizedBox(height: 8),
                                    Text(formatRupiah(item.product.price), style: AppTextStyles.priceSmall),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: () {
                                          if (item.quantity > 1) {
                                            provider.updateQuantity(item.product.id, item.quantity - 1);
                                          } else {
                                            provider.removeFromCart(item.product.id);
                                          }
                                        },
                                      ),
                                      Container(
                                        width: 40,
                                        height: 30,
                                        color: AppColors.surface,
                                        child: Center(child: Text('${item.quantity}')),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: () {
                                          provider.updateQuantity(item.product.id, item.quantity + 1);
                                        },
                                      ),
                                    ],
                                  ),
                                  Text(formatRupiah(item.subtotal), style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GlassCard(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Kode Kupon / Coupon Code',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ),
                GlassCard(
                  margin: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal'),
                          Text(formatRupiah(provider.totalPrice)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Estimasi Ongkir / Est. Shipping'),
                          Text('Rp 15.000'),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: AppTextStyles.titleMedium),
                          Text(formatRupiah(provider.totalPrice + 15000), style: AppTextStyles.price.copyWith(color: AppColors.accent)),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: GradientButton(
                    label: 'Checkout',
                    icon: Icons.payment,
                    onPressed: () {
                      Navigator.pushNamed(context, AppRouter.checkout);
                    },
                  ),
                ),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }
}
