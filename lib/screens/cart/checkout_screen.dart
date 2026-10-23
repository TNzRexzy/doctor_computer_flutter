import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/core/constants/app_constants.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'dart:math';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/providers/notification_provider.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/screens/map/location_picker_screen.dart';

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
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phone;
      _addressController.text = user.address;
      _cityController.text = user.city;
      _latitude = user.latitude;
      _longitude = user.longitude;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  void _openMapPicker() async {
    final result = await Navigator.pushNamed(
      context,
      AppRouter.locationPicker,
      arguments: {
        'lat': _latitude,
        'lng': _longitude,
        'address': _addressController.text,
      },
    );

    if (result is LocationPickerResult) {
      setState(() {
        _addressController.text = result.address;
        _cityController.text = result.city;
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Alamat dari peta berhasil dipilih dan tersimpan ke database!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

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
    await context.read<OrderProvider>().addOrder(newOrder);
    if (!mounted) return;

    // Decrement stock for each purchased item
    final productProvider = context.read<ProductProvider>();
    for (final item in cart.items) {
      productProvider.decrementStock(item.product.id, item.quantity);
    }

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
        title: 'Pesanan Berhasil: $orderId',
        message: 'Pesanan Anda senilai ${formatRupiah(newOrder.totalPrice)} sedang diproses untuk QC & perakitan aman.',
        type: 'order',
        actionRoute: AppRouter.orderHistory,
        actionLabel: 'Lacak Pesanan',
      );

      context.read<NotificationProvider>().addNotification(
        title: 'Bonus Belanja: +500 EXP!',
        message: 'Blok #${block.index} berhasil ditambang di Blockchain untuk transaksi $itemName. Akumulasi EXP: ${blockchain.totalExp} EXP.',
        type: 'tier_upgrade',
        actionRoute: AppRouter.membership,
        actionLabel: 'Lihat Blockchain',
      );

      if (newTier != oldTier) {
        context.read<NotificationProvider>().addNotification(
          title: 'Selamat! Upgrade ke Tier ${newTier.name.toUpperCase()}!',
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
                  Text('Blockchain Transaksi (Blok #${block.index}):', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              context.read<CartProvider>().clearCart();
              Navigator.pop(ctx); // Close dialog
              
              // Cleanly reset stack to MainNavScreen and navigate straight to Order History
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRouter.mainNav,
                (route) => false,
              );
              Navigator.pushNamed(context, AppRouter.orderHistory);
            },
            child: const Text('OK - Lihat Pesanan Saya'),
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

                // Alamat Pengiriman Header & Map Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Alamat Pengiriman', style: AppTextStyles.titleMedium),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _openMapPicker,
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('Pilih via Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Map Pin Status Badge
                if (_latitude != null && _longitude != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.pin_drop, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Titik Peta: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)} (Tersimpan di Database)',
                            style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                GlassCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                      ),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Nomor Telepon'),
                      ),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Alamat'),
                        maxLines: 2,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(labelText: 'Kota'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              controller: _postalController,
                              decoration: const InputDecoration(labelText: 'Kode Pos'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Metode Pengiriman', style: AppTextStyles.titleMedium),
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
                Text('Metode Pembayaran', style: AppTextStyles.titleMedium),
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
                      activeColor: AppColors.primary,
                    );
                  }),
                ),
                const SizedBox(height: 24),
                Text('Ringkasan Pesanan', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                GlassCard(
                  child: Consumer<CartProvider>(
                    builder: (context, cart, _) {
                      final shippingPrice = AppConstants.shippingMethods[_selectedShipping]['price'] as double;
                      final total = cart.totalPrice + shippingPrice;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal', style: AppTextStyles.bodyMedium),
                              Text(formatRupiah(cart.totalPrice), style: AppTextStyles.bodyMedium),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Ongkir', style: AppTextStyles.bodyMedium),
                              Text(formatRupiah(shippingPrice), style: AppTextStyles.bodyMedium),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Pembayaran', style: AppTextStyles.titleMedium),
                              Text(formatRupiah(total), style: AppTextStyles.price),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  label: _isProcessing ? 'Memproses Pesanan...' : 'Bayar Sekarang',
                  onPressed: _isProcessing ? () {} : _processPayment,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
