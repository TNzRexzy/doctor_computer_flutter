import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/core/constants/app_constants.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'dart:math';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/providers/notification_provider.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _selectedShipping = 0;
  int _selectedPayment = 0;
  bool _isProcessing = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalController = TextEditingController();

  void _processPayment() async {
    setState(() {
      _isProcessing = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isProcessing = false;
    });
    
    if (!mounted) return;
    final randomDigits = Random().nextInt(900000) + 100000;
    final orderId = 'DC-$randomDigits';
    final serial = 'SN-DC2026-$randomDigits';
    final cart = context.read<CartProvider>();
    final shipping = AppConstants.shippingMethods[_selectedShipping];
    final payment = AppConstants.paymentMethods[_selectedPayment];
    final fullAddress = '${_addressController.text.trim()}, ${_cityController.text.trim()} ${_postalController.text.trim()}';

    // 1. Create order in OrderProvider
    final newOrder = OrderModel(
      id: orderId,
      items: List<CartItemModel>.from(cart.items),
      totalPrice: cart.totalPrice + (shipping['price'] as double),
      status: OrderStatus.processing,
      orderDate: DateTime.now(),
      shippingAddress: fullAddress.isNotEmpty ? fullAddress : 'Jl. Merdeka No 1, Jakarta',
      paymentMethod: payment,
      trackingNumber: 'JNE-$randomDigits',
      courier: '${shipping['name']} (${shipping['days']} hari)',
      serialNumber: serial,
      warrantyDurationMonths: 24,
    );
    context.read<OrderProvider>().addOrder(newOrder);

    // 2. Mine Block 2: Belanja Komponen (+500 EXP)
    final itemName = cart.items.isNotEmpty ? cart.items.first.product.name : 'Komponen PC / RAM';
    final blockchain = context.read<BlockchainProvider>();
    final oldTier = blockchain.currentTier;
    final block = await blockchain.addShoppingReward(
      itemName: itemName,
      expEarned: 500,
    );
    final newTier = blockchain.currentTier;

    // 3. Add mobile notifications
    if (mounted) {
      context.read<NotificationProvider>().addNotification(
        title: '📦 Pesanan Berhasil: $orderId',
        message: 'Pesanan Anda senilai ${formatRupiah(newOrder.totalPrice)} sedang diproses untuk QC & perakitan aman.',
        type: 'order',
        actionRoute: AppRouter.orderHistory,
        actionLabel: 'Lacak Pesanan',
      );

      context.read<NotificationProvider>().addNotification(
        title: '💎 Bonus Belanja: +500 EXP!',
        message: 'Blok #${block.index} berhasil ditambang di Blockchain untuk transaksi $itemName. Akumulasi EXP: ${blockchain.totalExp} EXP.',
        type: 'tier_upgrade',
        actionRoute: AppRouter.membership,
        actionLabel: 'Lihat Blockchain',
      );

      if (newTier != oldTier) {
        context.read<NotificationProvider>().addNotification(
          title: '🏆 Selamat! Upgrade ke Tier ${newTier.name.toUpperCase()}!',
          message: 'Akumulasi EXP Anda mencapai ${blockchain.totalExp} EXP. Tier Anda otomatis naik ke ${newTier.name}!',
          type: 'tier_upgrade',
        );
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            const SizedBox(width: 8),
            const Text('Pesanan Berhasil!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: $orderId', style: AppTextStyles.titleSmall),
            const SizedBox(height: 4),
            Text('Nomor Seri: $serial (Garansi 24 Bulan)', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔗 Blockchain Transaksi (Blok #${block.index}):', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Reward: +500 EXP (Belanja $itemName)', style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                  Text('Akumulasi EXP: ${blockchain.totalExp} EXP', style: AppTextStyles.caption),
                  Text('Tier Member: ${newTier.name.toUpperCase()}', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold)),
                  Text('Hash: ${block.hash.substring(0, 16)}...', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<CartProvider>().clearCart();
              Navigator.pop(ctx);
              Navigator.popUntil(context, ModalRoute.withName(AppRouter.mainNav));
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text('Checkout', style: AppTextStyles.heading3),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Alamat Pengiriman / Shipping Address', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nama Lengkap / Full Name'),
                      ),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Nomor Telepon / Phone Number'),
                      ),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Alamat / Address'),
                        maxLines: 2,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(labelText: 'Kota / City'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              controller: _postalController,
                              decoration: const InputDecoration(labelText: 'Kode Pos / Postal'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Metode Pengiriman / Shipping Method', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                Column(
                  children: List.generate(AppConstants.shippingMethods.length, (index) {
                    final method = AppConstants.shippingMethods[index];
                    return RadioListTile<int>(
                      value: index,
                      groupValue: _selectedShipping,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedShipping = val);
                      },
                      title: Text(method['name'] as String),
                      subtitle: Text(method['days'] as String),
                      secondary: Text(formatRupiah(method['price'] as double)),
                      activeColor: AppColors.primary,
                    );
                  }),
                ),
                const SizedBox(height: 24),
                Text('Metode Pembayaran / Payment Method', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                Column(
                  children: List.generate(AppConstants.paymentMethods.length, (index) {
                    final method = AppConstants.paymentMethods[index];
                    return RadioListTile<int>(
                      value: index,
                      groupValue: _selectedPayment,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPayment = val);
                      },
                      title: Text(method),
                      secondary: const Icon(Icons.payment),
                      activeColor: AppColors.primary,
                    );
                  }),
                ),
                const SizedBox(height: 24),
                Text('Ringkasan Pesanan / Order Summary', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                Consumer<CartProvider>(
                  builder: (context, provider, child) {
                    final shippingFee = AppConstants.shippingMethods[_selectedShipping]['price'] as double;
                    final grandTotal = provider.totalPrice + shippingFee;
                    return GlassCard(
                      child: Column(
                        children: [
                          ...provider.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text('${item.product.name} x${item.quantity}')),
                                  Text(formatRupiah(item.subtotal)),
                                ],
                              ),
                            );
                          }),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal'),
                              Text(formatRupiah(provider.totalPrice)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ongkir / Shipping'),
                              Text(formatRupiah(shippingFee)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Pembayaran / Total Payment', style: AppTextStyles.titleMedium),
                              Text(formatRupiah(grandTotal), style: AppTextStyles.price),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Bayar Sekarang / Pay Now',
                  isLoading: _isProcessing,
                  onPressed: _processPayment,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

