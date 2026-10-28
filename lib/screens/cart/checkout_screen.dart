import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/core/constants/app_constants.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/providers/notification_provider.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/screens/map/location_picker_screen.dart';
import 'package:doctor_computer/widgets/common/app_toast.dart';

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
        AppToast.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Alamat dari peta berhasil dipilih dan tersimpan ke database!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _buildSectionHeading(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceCard({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.cardBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildShippingOption(int index) {
    final method = AppConstants.shippingMethods[index];
    final selected = _selectedShipping == index;
    final deliveryEstimate = method['days'] as String;

    return _buildChoiceCard(
      selected: selected,
      onTap: () => setState(() => _selectedShipping = index),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method['name'] as String, style: AppTextStyles.titleSmall),
                const SizedBox(height: 3),
                Text(
                  deliveryEstimate.toLowerCase().contains('hari')
                      ? deliveryEstimate
                      : 'Estimasi $deliveryEstimate hari',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRupiah(method['price'] as double),
            style: AppTextStyles.titleSmall.copyWith(
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(int index) {
    final method = AppConstants.paymentMethods[index];
    final selected = _selectedPayment == index;
    final usesWallet =
        method.contains('GoPay') ||
        method.contains('OVO') ||
        method.contains('Dana') ||
        method.contains('ShopeePay');
    final icon = method == 'COD'
        ? Icons.local_shipping_outlined
        : usesWallet
        ? Icons.account_balance_wallet_outlined
        : Icons.account_balance_outlined;

    return _buildChoiceCard(
      selected: selected,
      onTap: () => setState(() => _selectedPayment = index),
      child: Row(
        children: [
          Icon(
            icon,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(method, style: AppTextStyles.bodyMedium)),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  void _processPayment() async {
    setState(() {
      _isProcessing = true;
    });
    final cart = context.read<CartProvider>();
    final shipping = AppConstants.shippingMethods[_selectedShipping];
    final payment = AppConstants.paymentMethods[_selectedPayment];
    final fullAddress =
        '${_addressController.text.trim()}, ${_cityController.text.trim()} ${_postalController.text.trim()}';

    final voucherDiscount = cart.voucherDiscountForShipping(
      shipping['price'] as double,
    );
    final orderRequest = OrderModel(
      id: '',
      items: List<CartItemModel>.from(cart.items),
      totalPrice:
          cart.totalPrice + (shipping['price'] as double) - voucherDiscount,
      status: OrderStatus.processing,
      orderDate: DateTime.now(),
      shippingAddress: fullAddress.isNotEmpty
          ? fullAddress
          : 'Jl. Merdeka No 1, Jakarta',
      paymentMethod: payment,
      courier: '${shipping['name']} (${shipping['days']} hari)',
      warrantyDurationMonths: 24,
    );
    final order = await context.read<OrderProvider>().addOrder(
      orderRequest,
      shippingMethod: shipping['name'] as String,
      voucherCode: cart.appliedVoucherCode,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (order == null) {
      final error =
          context.read<OrderProvider>().errorMessage ??
          'Pesanan gagal disimpan.';
      AppToast.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }

    final orderId = order.id;
    final serial = order.serialNumber;

    if (mounted) {
      context.read<NotificationProvider>().addNotification(
        title: 'Pesanan Berhasil: $orderId',
        message:
            'Pesanan Anda senilai ${formatRupiah(order.totalPrice)} sedang diproses untuk QC & perakitan aman.',
        type: 'order',
        actionRoute: AppRouter.orderHistory,
        actionLabel: 'Lacak Pesanan',
      );
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
            Text(
              'Nomor Seri: $serial (Garansi 24 Bulan)',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Poin loyalitas hanya diberikan setelah pesanan dikonfirmasi selesai.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Checkout', style: AppTextStyles.heading3),
                        Text(
                          'Lengkapi detail pesanan Anda',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionHeading(
                  Icons.location_on_outlined,
                  'Alamat pengiriman',
                  'Pastikan alamat dan nomor kontak sudah benar.',
                ),
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 20,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Detail penerima',
                              style: AppTextStyles.titleSmall,
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.6),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _openMapPicker,
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('Pilih di peta'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nama lengkap',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Nomor telepon',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _addressController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Alamat lengkap',
                          hintText: 'Nama jalan, nomor rumah, RT/RW, patokan',
                          prefixIcon: Icon(Icons.home_outlined),
                          alignLabelWithHint: true,
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _cityController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Kota / Kabupaten',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _postalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kode pos',
                          prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                        ),
                      ),
                      if (_latitude != null && _longitude != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.pin_drop_outlined,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pin peta terpasang · ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeading(
                  Icons.local_shipping_outlined,
                  'Metode pengiriman',
                  'Pilih layanan yang sesuai dengan kebutuhan Anda.',
                ),
                Column(
                  children: List.generate(AppConstants.shippingMethods.length, (
                    index,
                  ) {
                    return _buildShippingOption(index);
                  }),
                ),
                const SizedBox(height: 24),
                _buildSectionHeading(
                  Icons.account_balance_wallet_outlined,
                  'Metode pembayaran',
                  'Pilih cara pembayaran untuk pesanan ini.',
                ),
                Column(
                  children: List.generate(AppConstants.paymentMethods.length, (
                    index,
                  ) {
                    return _buildPaymentOption(index);
                  }),
                ),
                const SizedBox(height: 24),
                _buildSectionHeading(
                  Icons.receipt_long_outlined,
                  'Ringkasan pesanan',
                  'Periksa kembali total sebelum membuat pesanan.',
                ),
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 20,
                  child: Consumer<CartProvider>(
                    builder: (context, cart, _) {
                      final shippingPrice =
                          AppConstants
                                  .shippingMethods[_selectedShipping]['price']
                              as double;
                      final total = cart.totalPrice + shippingPrice;
                      final voucherDiscount = cart.voucherDiscountForShipping(
                        shippingPrice,
                      );

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal', style: AppTextStyles.bodyMedium),
                              Text(
                                formatRupiah(cart.totalPrice),
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Ongkir', style: AppTextStyles.bodyMedium),
                              Text(
                                formatRupiah(shippingPrice),
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                          if (voucherDiscount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Voucher ${cart.appliedVoucherCode ?? ''}',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                Text(
                                  '- ${formatRupiah(voucherDiscount)}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Pembayaran',
                                style: AppTextStyles.titleMedium,
                              ),
                              Text(
                                formatRupiah(total - voucherDiscount),
                                style: AppTextStyles.price,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  label: _isProcessing
                      ? 'Memproses Pesanan...'
                      : 'Bayar Sekarang',
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
