import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/order_update_dialog.dart';
import 'package:doctor_computer/widgets/admin/product_editor_dialog.dart';
import 'package:doctor_computer/widgets/review/review_management_tab.dart';
import 'package:doctor_computer/services/product_image_storage_service.dart';
import 'package:doctor_computer/core/constants/app_images.dart';
import 'package:doctor_computer/widgets/common/global_pull_to_refresh.dart';

class CashierDashboardScreen extends StatefulWidget {
  const CashierDashboardScreen({super.key});

  @override
  State<CashierDashboardScreen> createState() => _CashierDashboardScreenState();
}

class _CashierDashboardScreenState extends State<CashierDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, dynamic>? _currentShift;
  List<Map<String, dynamic>> _shiftHistory = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _managedProducts = [];
  List<Map<String, dynamic>> _posOrders = [];
  List<Map<String, dynamic>> _allOrders = [];

  // POS Cart: Map of productId -> quantity
  final Map<String, int> _cart = {};

  String _productSearchQuery = '';
  String _selectedCategory = 'all';
  String _orderSearchQuery = '';
  String _manageOrderSearchQuery = '';
  String _manageOrderChannelFilter = 'all'; // 'all', 'online', 'pos'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadCashierData();
    PageRefreshRegistry.register(_loadCashierData);
  }

  @override
  void dispose() {
    PageRefreshRegistry.unregister(_loadCashierData);
    _tabController.dispose();
    super.dispose();
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    final n = number is num ? number : num.tryParse(number.toString()) ?? 0;
    return n
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );
  }

  String _getCashierId() {
    return supabase.auth.currentUser?.id ?? '';
  }

  String _getCashierName() {
    final user = context.read<AuthProvider>().currentUser;
    return user?.fullName ?? 'Kasir';
  }

  Future<void> _loadCashierData() async {
    setState(() => _isLoading = true);
    final cashierId = _getCashierId();

    try {
      try {
        final shiftRes = await supabase
            .from('cashier_shifts')
            .select()
            .eq('cashier_id', cashierId)
            .eq('status', 'open')
            .maybeSingle();
        _currentShift = shiftRes != null
            ? Map<String, dynamic>.from(shiftRes)
            : null;
      } catch (e) {
        debugPrint('Notice loading active shift from Supabase: $e');
        _currentShift = null;
      }

      try {
        final historyRes = await supabase
            .from('cashier_shifts')
            .select()
            .eq('cashier_id', cashierId)
            .order('opened_at', ascending: false)
            .limit(20);
        _shiftHistory = List<Map<String, dynamic>>.from(historyRes);
      } catch (e) {
        debugPrint('Notice loading shift history: $e');
      }

      // 3. Fetch products (merge Supabase + ProductProvider)
      try {
        final productsRes = await supabase
            .from('products')
            .select()
            .order('created_at', ascending: false);
        final Map<String, Map<String, dynamic>> pMap = {};
        for (final p in productsRes) {
          final id = p['id']?.toString() ?? '';
          if (id.isNotEmpty) pMap[id] = Map<String, dynamic>.from(p);
        }
        _managedProducts = pMap.values.toList();
        if (mounted) {
          final providerProducts = context.read<ProductProvider>().allProducts;
          for (final p in providerProducts) {
            if (!pMap.containsKey(p.id)) {
              pMap[p.id] = p.toMap();
            }
          }
        }
        _products = pMap.values.toList();
      } catch (e) {
        debugPrint('Notice loading products: $e');
      }

      // 4. Fetch POS orders from Supabase
      try {
        List<dynamic> ordersRes;
        try {
          ordersRes = await supabase
              .from('orders')
              .select()
              .eq('channel', 'pos')
              .order('order_date', ascending: false)
              .limit(50);
        } catch (_) {
          try {
            ordersRes = await supabase
                .from('orders')
                .select()
                .order('created_at', ascending: false)
                .limit(50);
          } catch (_) {
            ordersRes = await supabase.from('orders').select().limit(50);
          }
        }
        final filtered = ordersRes.where((o) {
          final ch = o['channel']?.toString().toLowerCase();
          return ch == null || ch == 'pos' || ch.isEmpty;
        }).toList();
        _posOrders = List<Map<String, dynamic>>.from(filtered);
      } catch (e) {
        debugPrint('Notice loading POS orders: $e');
      }

      // 5. Fetch all orders (online + POS) for the Pesanan management tab
      try {
        List<dynamic> allRes;
        try {
          allRes = await supabase
              .from('orders')
              .select()
              .order('order_date', ascending: false)
              .limit(200);
        } catch (_) {
          allRes = await supabase
              .from('orders')
              .select()
              .order('created_at', ascending: false)
              .limit(200);
        }
        _allOrders = allRes
            .map((o) => Map<String, dynamic>.from(o as Map))
            .toList();
      } catch (e) {
        debugPrint('Notice loading all orders: $e');
      }
    } catch (e) {
      debugPrint('Error loading cashier data: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ============================================================
  // SHIFT MANAGEMENT ACTIONS
  // ============================================================
  void _showOpenShiftDialog() {
    final cashCtrl = TextEditingController(text: '100000');
    final notesCtrl = TextEditingController(text: 'Shift Pagi');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.point_of_sale, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Buka Shift Kasir', style: AppTextStyles.titleMedium),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kasir: ${_getCashierName()}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cashCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Modal Awal Kas di Laci (Rp) *',
                    border: OutlineInputBorder(),
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Shift (Opsional)',
                    border: OutlineInputBorder(),
                    hintText: 'Misal: Shift Pagi Toko Utama',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final cash =
                          double.tryParse(cashCtrl.text.replaceAll('.', '')) ??
                          0;
                      setDialogState(() => isSubmitting = true);

                      try {
                        final response = await supabase.rpc(
                          'open_cashier_shift',
                          params: {
                            'p_opening_cash': cash,
                            'p_notes': notesCtrl.text.trim(),
                          },
                        );
                        if (response is! Map) {
                          throw const FormatException(
                            'Respons open_cashier_shift tidak valid.',
                          );
                        }
                        final newShiftData = Map<String, dynamic>.from(
                          response,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Shift kasir berhasil dibuka di server.',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          setState(() => _currentShift = newShiftData);
                          _loadCashierData();
                        }
                      } catch (e) {
                        debugPrint('open_cashier_shift failed: $e');
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Shift gagal dibuka: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: Text(isSubmitting ? 'Membuka...' : 'Buka Shift'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseShiftDialog() {
    if (_currentShift == null) return;

    final openingCash = _parseDouble(_currentShift!['opening_cash']);
    final totalSales = _parseDouble(_currentShift!['total_sales']);
    final totalOrders = _currentShift!['total_orders'] ?? 0;
    final expectedCash = openingCash + totalSales;

    final closingCashCtrl = TextEditingController(
      text: expectedCash.toStringAsFixed(0),
    );
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final counted =
              double.tryParse(closingCashCtrl.text.replaceAll('.', '')) ?? 0;
          final variance = counted - expectedCash;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.lock_clock, color: AppColors.warning),
                const SizedBox(width: 8),
                Text('Tutup Shift Kasir', style: AppTextStyles.titleMedium),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryRow(
                          'Modal Kas Awal:',
                          'Rp ${_formatNumber(openingCash)}',
                        ),
                        const SizedBox(height: 4),
                        _buildSummaryRow(
                          'Total Penjualan Shift:',
                          'Rp ${_formatNumber(totalSales)}',
                        ),
                        const SizedBox(height: 4),
                        _buildSummaryRow(
                          'Total Transaksi:',
                          '$totalOrders pesanan',
                        ),
                        const Divider(height: 16),
                        _buildSummaryRow(
                          'Estimasi Uang di Laci:',
                          'Rp ${_formatNumber(expectedCash)}',
                          isBold: true,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: closingCashCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Uang Fisik Aktual di Kasir *',
                      border: OutlineInputBorder(),
                      prefixText: 'Rp ',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selisih Kas (Variance):',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        variance == 0
                            ? 'Pas (Rp 0)'
                            : variance > 0
                            ? '+ Rp ${_formatNumber(variance)} (Lebih)'
                            : '- Rp ${_formatNumber(variance.abs())} (Kurang)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: variance == 0
                              ? AppColors.success
                              : variance > 0
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Penutupan Shift',
                      border: OutlineInputBorder(),
                      hintText: 'Misal: Kas klop, serah terima ke shift malam',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final shiftId = _currentShift!['id']?.toString() ?? '';
                        setDialogState(() => isSubmitting = true);

                        try {
                          await supabase.rpc(
                            'close_cashier_shift',
                            params: {
                              'p_shift_id': shiftId,
                              'p_closing_cash': counted,
                              'p_notes': notesCtrl.text.trim(),
                            },
                          );
                        } catch (e) {
                          debugPrint('close_cashier_shift failed: $e');
                          if (ctx.mounted) {
                            setDialogState(() => isSubmitting = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Shift gagal ditutup: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                          return;
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Shift kasir berhasil ditutup.',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          setState(() {
                            _currentShift = null;
                          });
                          _loadCashierData();
                        }
                      },
                child: Text(isSubmitting ? 'Menutup...' : 'Tutup Shift'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // POS CART ACTIONS & CHECKOUT
  // ============================================================
  void _addToCart(Map<String, dynamic> product) {
    if (_currentShift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Buka shift kasir terlebih dahulu untuk transaksi!',
          ),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Buka Shift',
            textColor: Colors.white,
            onPressed: _showOpenShiftDialog,
          ),
        ),
      );
      return;
    }

    final id = product['id']?.toString() ?? '';
    final stock = _parseInt(product['stock']);
    final currentQty = _cart[id] ?? 0;

    if (currentQty >= stock) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Stok tidak mencukupi!')));
      return;
    }

    setState(() {
      _cart[id] = currentQty + 1;
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      final current = _cart[productId] ?? 0;
      if (current <= 1) {
        _cart.remove(productId);
      } else {
        _cart[productId] = current - 1;
      }
    });
  }

  double _calculateSubtotal() {
    double total = 0.0;
    for (final entry in _cart.entries) {
      final prod = _products.firstWhere(
        (p) => p['id']?.toString() == entry.key,
        orElse: () => {},
      );
      if (prod.isNotEmpty) {
        final price = _parseDouble(prod['price']);
        total += price * entry.value;
      }
    }
    return total;
  }

  void _showCheckoutDialog() {
    if (_cart.isEmpty) return;
    if (_currentShift == null) {
      _showOpenShiftDialog();
      return;
    }

    final subtotal = _calculateSubtotal();
    String paymentMethod = 'Cash';
    final tenderedCtrl = TextEditingController(
      text: subtotal.toStringAsFixed(0),
    );
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final tendered =
              double.tryParse(tenderedCtrl.text.replaceAll('.', '')) ?? 0;
          final change = tendered - subtotal;
          final canPay = paymentMethod != 'Cash' || tendered >= subtotal;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.payment, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Pembayaran POS', style: AppTextStyles.titleMedium),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total tagihan
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text('Total Pembayaran', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${_formatNumber(subtotal)}',
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Metode Pembayaran:', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPaymentOption(
                        'Cash',
                        paymentMethod,
                        (m) => setDialogState(() => paymentMethod = m),
                      ),
                      const SizedBox(width: 8),
                      _buildPaymentOption(
                        'QRIS',
                        paymentMethod,
                        (m) => setDialogState(() => paymentMethod = m),
                      ),
                      const SizedBox(width: 8),
                      _buildPaymentOption(
                        'Debit BCA',
                        paymentMethod,
                        (m) => setDialogState(() => paymentMethod = m),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (paymentMethod == 'Cash') ...[
                    TextField(
                      controller: tenderedCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Uang Tunai Diterima *',
                        border: OutlineInputBorder(),
                        prefixText: 'Rp ',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildQuickAmountChip(
                          'Pas',
                          subtotal,
                          tenderedCtrl,
                          () => setDialogState(() {}),
                        ),
                        _buildQuickAmountChip(
                          '50rb',
                          50000,
                          tenderedCtrl,
                          () => setDialogState(() {}),
                        ),
                        _buildQuickAmountChip(
                          '100rb',
                          100000,
                          tenderedCtrl,
                          () => setDialogState(() {}),
                        ),
                        _buildQuickAmountChip(
                          '200rb',
                          200000,
                          tenderedCtrl,
                          () => setDialogState(() {}),
                        ),
                        _buildQuickAmountChip(
                          '500rb',
                          500000,
                          tenderedCtrl,
                          () => setDialogState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kembalian:', style: AppTextStyles.bodyMedium),
                        Text(
                          change >= 0
                              ? 'Rp ${_formatNumber(change)}'
                              : 'Uang kurang Rp ${_formatNumber(change.abs())}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: change >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            paymentMethod == 'QRIS'
                                ? Icons.qr_code
                                : Icons.credit_card,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              paymentMethod == 'QRIS'
                                  ? 'Tunjukkan QRIS kasir ke pelanggan untuk discan.'
                                  : 'Proses pembayaran menggunakan mesin EDC/Kartu.',
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: (!canPay || isSubmitting)
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        final completed = await _processCheckout(
                          dialogCtx: ctx,
                          paymentMethod: paymentMethod,
                          subtotal: subtotal,
                          tendered: tendered,
                        );
                        if (!completed && ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                      },
                child: Text(
                  isSubmitting ? 'Memproses...' : 'Selesaikan Transaksi',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentOption(
    String method,
    String selected,
    ValueChanged<String> onSelect,
  ) {
    final isSelected = method == selected;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(method),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              method,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountChip(
    String label,
    double amount,
    TextEditingController ctrl,
    VoidCallback onUpdate,
  ) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        ctrl.text = amount.toStringAsFixed(0);
        onUpdate();
      },
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Future<bool> _processCheckout({
    required BuildContext dialogCtx,
    required String paymentMethod,
    required double subtotal,
    required double tendered,
  }) async {
    final cashierId = _getCashierId();
    final cashierName = _getCashierName();
    final productProvider = context.read<ProductProvider>();
    final orderProvider = context.read<OrderProvider>();

    final List<Map<String, dynamic>> itemsPayload = [];
    for (final entry in _cart.entries) {
      itemsPayload.add({'product_id': entry.key, 'quantity': entry.value});
    }

    try {
      final rpcRes = await supabase.rpc(
        'create_pos_order',
        params: {
          'p_cashier_id': cashierId,
          'p_total_price': subtotal,
          'p_payment_method': paymentMethod,
          'p_items': itemsPayload,
        },
      );
      if (rpcRes is! Map) {
        throw const FormatException('Respons create_pos_order tidak valid.');
      }
      final order = Map<String, dynamic>.from(rpcRes);
      final orderId = order['id']?.toString();
      final totalPrice = (order['total_price'] as num?)?.toDouble();
      final rawItems = order['items'];
      if (orderId == null ||
          orderId.isEmpty ||
          totalPrice == null ||
          rawItems is! List) {
        throw const FormatException('Respons create_pos_order tidak lengkap.');
      }
      final receiptItems = rawItems.map((rawItem) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        final price = (item['unit_price'] as num).toDouble();
        final quantity = (item['quantity'] as num).toInt();
        return <String, dynamic>{
          'name': item['product_name'] ?? 'Produk',
          'quantity': quantity,
          'unit_price': price,
          'subtotal': price * quantity,
        };
      }).toList();

      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      if (mounted) {
        setState(() => _cart.clear());
        await _loadCashierData();
        productProvider.reloadData();
        orderProvider.reloadOrders();
        _showReceiptDialog(
          orderId: orderId,
          cashierName: cashierName,
          items: receiptItems,
          totalPrice: totalPrice,
          paymentMethod: paymentMethod,
          tendered: tendered,
          change: tendered - totalPrice,
        );
      }
      return true;
    } catch (e) {
      debugPrint('create_pos_order failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaksi gagal disimpan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
  }

  void _showReceiptDialog({
    required String orderId,
    required String cashierName,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String paymentMethod,
    required double tendered,
    required double change,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 48),
                const SizedBox(height: 8),
                Text('Transaksi Berhasil!', style: AppTextStyles.titleMedium),
                const SizedBox(height: 16),

                // Struk Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'DOCTOR COMPUTER STORE',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Sistem Kasir & POS Omnichannel',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'Jl. Elektronik Komputer No. 10',
                        style: AppTextStyles.caption,
                      ),
                      const Divider(height: 20),

                      _buildSummaryRow('No. Nota:', orderId),
                      _buildSummaryRow(
                        'Tanggal:',
                        DateTime.now().toString().split('.').first,
                      ),
                      _buildSummaryRow('Kasir:', cashierName),
                      const Divider(height: 20),

                      ...items.map(
                        (it) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it['name']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${it['quantity']} x Rp ${_formatNumber(it['unit_price'])}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Rp ${_formatNumber(it['subtotal'])}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(height: 20),
                      _buildSummaryRow(
                        'TOTAL:',
                        'Rp ${_formatNumber(totalPrice)}',
                        isBold: true,
                      ),
                      _buildSummaryRow('Metode:', paymentMethod),
                      if (paymentMethod == 'Cash') ...[
                        _buildSummaryRow(
                          'Tunai:',
                          'Rp ${_formatNumber(tendered)}',
                        ),
                        _buildSummaryRow(
                          'Kembalian:',
                          'Rp ${_formatNumber(change)}',
                          color: AppColors.success,
                        ),
                      ],
                      const Divider(height: 20),
                      Text(
                        'Terima Kasih Atas Kunjungan Anda!',
                        style: AppTextStyles.caption.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Cetak Struk'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Perintah cetak dikirim ke printer POS!'),
                ),
              );
              Navigator.pop(ctx);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai / Transaksi Baru'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isOpen = _currentShift != null;
    final cashierName = _getCashierName();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Kasir & POS',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Kasir: $cashierName',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6D28D9), // Purple accent for cashier
        foregroundColor: Colors.white,
        actions: [
          // Shift status pill
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: InkWell(
              onTap: isOpen ? _showCloseShiftDialog : _showOpenShiftDialog,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isOpen ? Colors.green.shade600 : Colors.red.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOpen ? Icons.check_circle : Icons.lock,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOpen ? 'SHIFT OPEN' : 'SHIFT CLOSED',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCashierData,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.point_of_sale),
              text: 'Mesin Kasir (${_cart.values.fold(0, (a, b) => a + b)})',
            ),
            const Tab(icon: Icon(Icons.schedule), text: 'Kelola Shift'),
            const Tab(
              icon: Icon(Icons.receipt_long),
              text: 'Riwayat Transaksi',
            ),
            const Tab(icon: Icon(Icons.local_shipping), text: 'Pesanan'),
            const Tab(icon: Icon(Icons.inventory_2), text: 'Cek Stok'),
            const Tab(icon: Icon(Icons.edit_note), text: 'Kelola Produk'),
            const Tab(icon: Icon(Icons.star_rate), text: 'Ulasan'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPOSTab(),
                _buildShiftTab(),
                _buildOrdersTab(),
                _buildOrderManagementTab(),
                _buildStockTab(),
                _buildProductManagementTab(),
                const ReviewManagementTab(),
              ],
            ),
    );
  }

  // ============================================================
  // TAB 1: MESIN KASIR / POS
  // ============================================================
  Widget _buildPOSTab() {
    final isOpen = _currentShift != null;
    final subtotal = _calculateSubtotal();
    final totalItems = _cart.values.fold(0, (a, b) => a + b);

    final filteredProducts = _products.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final brand = p['brand']?.toString().toLowerCase() ?? '';
      final cat = p['category_id']?.toString().toLowerCase() ?? '';
      final matchesQuery =
          _productSearchQuery.isEmpty ||
          name.contains(_productSearchQuery.toLowerCase()) ||
          brand.contains(_productSearchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'all' || cat == _selectedCategory;
      return matchesQuery && matchesCat;
    }).toList();

    return Column(
      children: [
        // Shift alert if closed
        if (!isOpen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.warning.withValues(alpha: 0.15),
            child: Row(
              children: [
                Icon(Icons.info, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Shift kasir sedang tutup. Buka shift untuk melayani transaksi.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _showOpenShiftDialog,
                  child: const Text(
                    'Buka Shift',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

        // Product search & category chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari produk POS (nama / brand)...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _productSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _productSearchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onChanged: (val) => setState(() => _productSearchQuery = val),
          ),
        ),

        // Categories
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _buildCategoryChip('all', 'Semua'),
              ..._posCategoryOptions().map(
                (c) => _buildCategoryChip(c.key, c.value),
              ),
            ],
          ),
        ),

        // Product Grid
        Expanded(
          child: filteredProducts.isEmpty
              ? const Center(child: Text('Tidak ada produk yang cocok.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final p = filteredProducts[index];
                    final pid = p['id']?.toString() ?? '';
                    final stock = _parseInt(p['stock']);
                    final price = _parseDouble(p['price']);
                    final inCartQty = _cart[pid] ?? 0;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: inCartQty > 0
                            ? const BorderSide(
                                color: Color(0xFF8B5CF6),
                                width: 2,
                              )
                            : BorderSide(color: AppColors.cardBorder),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: stock > 0 ? () => _addToCart(p) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top badge: stock & cart badge
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: stock > 5
                                          ? AppColors.success.withValues(
                                              alpha: 0.15,
                                            )
                                          : (stock > 0
                                                ? AppColors.warning.withValues(
                                                    alpha: 0.15,
                                                  )
                                                : AppColors.error.withValues(
                                                    alpha: 0.15,
                                                  )),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      stock > 0 ? 'Stok: $stock' : 'Habis',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: stock > 5
                                            ? AppColors.success
                                            : (stock > 0
                                                  ? AppColors.warning
                                                  : AppColors.error),
                                      ),
                                    ),
                                  ),
                                  if (inCartQty > 0)
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      child: Text(
                                        '$inCartQty',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: _buildPosProductImage(p),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p['name']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p['brand']?.toString() ?? '',
                                style: AppTextStyles.caption,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Rp ${_formatNumber(price)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_shopping_cart,
                                      size: 16,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    color: const Color(0xFF8B5CF6),
                                    onPressed: stock > 0
                                        ? () => _addToCart(p)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Cart Drawer / Bottom Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expandable Cart items if any
              if (_cart.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView(
                    shrinkWrap: true,
                    children: _cart.entries.map((entry) {
                      final prod = _products.firstWhere(
                        (p) => p['id']?.toString() == entry.key,
                        orElse: () => {},
                      );
                      final name = prod['name'] ?? 'Item';
                      final price = _parseDouble(prod['price']);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$name',
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 16,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _removeFromCart(entry.key),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '${entry.value}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 16,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _addToCart(prod),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Rp ${_formatNumber(price * entry.value)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Bottom action row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalItems Item di Keranjang',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'Rp ${_formatNumber(subtotal)}',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_cart.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _cart.clear()),
                          child: Text(
                            'Reset',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(
                          Icons.payment,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Bayar POS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _cart.isEmpty ? null : _showCheckoutDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Daftar kategori untuk chip POS: diambil dari kategori di database
  /// (ProductProvider) dan hanya yang benar-benar dipakai produk di kasir.
  List<MapEntry<String, String>> _posCategoryOptions() {
    final used = <String>{};
    for (final p in _products) {
      final c = p['category_id']?.toString().toLowerCase() ?? '';
      if (c.isNotEmpty) used.add(c);
    }
    final labels = <String, String>{};
    try {
      for (final c in context.read<ProductProvider>().categories) {
        final label = c.nameId.isNotEmpty ? c.nameId : c.name;
        labels[c.id.toLowerCase()] = label;
      }
    } catch (_) {}
    final result = <MapEntry<String, String>>[];
    for (final id in used) {
      result.add(MapEntry(id, labels[id] ?? id));
    }
    result.sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return result;
  }

  Widget _buildPosProductImage(Map<String, dynamic> p) {
    final pid = p['id']?.toString() ?? '';
    final name = p['name']?.toString() ?? '';
    final brand = p['brand']?.toString();
    final candidates = <String>[];
    void add(String? u) {
      final v = u?.trim() ?? '';
      if (v.isEmpty) return;
      if (!candidates.contains(v)) candidates.add(v);
      final alt = AppImages.getPublicFallbackUrl(v);
      if (alt.isNotEmpty && !candidates.contains(alt)) candidates.add(alt);
    }

    for (final u in AppImages.resolveProductImages(
      p['image_url'] ?? p['images'],
      pid,
      productName: name,
      categoryId: p['category_id']?.toString(),
      brand: brand,
    )) {
      add(u);
    }
    final matched = AppImages.matchUploadedImage(name, brand);
    if (matched != null) add(AppImages.getBucketUrl(matched));
    if (pid.isNotEmpty) add(AppImages.getProductImageUrl(pid));
    return _PosImageChain(urls: candidates);
  }

  Widget _buildCategoryChip(String catId, String label) {
    final isSelected = _selectedCategory == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : null,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFF6D28D9),
        checkmarkColor: Colors.white,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() => _selectedCategory = catId),
      ),
    );
  }

  // ============================================================
  // TAB 2: KELOLA SHIFT
  // ============================================================
  Widget _buildShiftTab() {
    final isOpen = _currentShift != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current shift card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status Shift Saat Ini',
                      style: AppTextStyles.titleMedium,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isOpen ? AppColors.success : Colors.grey)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOpen ? 'AKTIF / TERBUKA' : 'TIDAK AKTIF / TUTUP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOpen ? AppColors.success : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (isOpen) ...[
                  _buildSummaryRow(
                    'ID Shift:',
                    _currentShift!['id']?.toString() ?? '-',
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'Waktu Dibuka:',
                    _currentShift!['opened_at']?.toString().split('.').first ??
                        '-',
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'Modal Kas Awal:',
                    'Rp ${_formatNumber(_currentShift!['opening_cash'])}',
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'Total Penjualan:',
                    'Rp ${_formatNumber(_currentShift!['total_sales'])}',
                    isBold: true,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'Jumlah Transaksi:',
                    '${_currentShift!['total_orders'] ?? 0} pesanan',
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'Catatan:',
                    _currentShift!['notes']?.toString() ?? '-',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      icon: const Icon(Icons.lock_clock),
                      label: const Text('Tutup Shift Sekarang'),
                      onPressed: _showCloseShiftDialog,
                    ),
                  ),
                ] else ...[
                  const Text('Saat ini Anda tidak memiliki shift aktif.'),
                  const SizedBox(height: 8),
                  Text(
                    'Buka shift terlebih dahulu sebelum menerima transaksi pelanggan di toko.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      icon: Icon(Icons.point_of_sale, color: Colors.white),
                      label: const Text('Mulai Buka Shift Kasir'),
                      onPressed: _showOpenShiftDialog,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Shift History
          Text('Riwayat Shift Terdahulu', style: AppTextStyles.titleMedium),
          const SizedBox(height: 10),
          if (_shiftHistory.isEmpty)
            const Center(child: Text('Belum ada riwayat shift.'))
          else
            ..._shiftHistory.map((shift) {
              final isShiftOpen = shift['status'] == 'open';
              final openedAt = shift['opened_at'] != null
                  ? shift['opened_at'].toString().split('.').first
                  : '-';
              final sales = _parseDouble(shift['total_sales']);
              final orders = shift['total_orders'] ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (isShiftOpen ? AppColors.success : Colors.grey)
                            .withValues(alpha: 0.15),
                    child: Icon(
                      isShiftOpen ? Icons.lock_open : Icons.lock,
                      color: isShiftOpen ? AppColors.success : Colors.grey,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Buka: $openedAt',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Penjualan: Rp ${_formatNumber(sales)} • $orders pesanan',
                    style: AppTextStyles.caption,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isShiftOpen ? AppColors.success : Colors.grey)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isShiftOpen ? 'OPEN' : 'CLOSED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isShiftOpen ? AppColors.success : Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: RIWAYAT TRANSAKSI POS
  // ============================================================
  Widget _buildOrdersTab() {
    final filtered = _posOrders.where((o) {
      final id = o['id']?.toString().toLowerCase() ?? '';
      final cashier = o['cashier_id']?.toString().toLowerCase() ?? '';
      return _orderSearchQuery.isEmpty ||
          id.contains(_orderSearchQuery.toLowerCase()) ||
          cashier.contains(_orderSearchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari nota POS (No. Transaksi)...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
            onChanged: (val) => setState(() => _orderSearchQuery = val),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Total: ${filtered.length} transaksi POS',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Belum ada transaksi POS.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    final date = order['order_date'] != null
                        ? order['order_date'].toString().split('.').first
                        : '-';
                    final total = _parseDouble(order['total_price']);
                    final method = order['payment_method'] ?? 'Cash';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6D28D9)
                              .withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.receipt,
                            color: Color(0xFF6D28D9),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          order['id']?.toString() ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'Waktu: $date\nMetode: $method',
                          style: AppTextStyles.caption,
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rp ${_formatNumber(total)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SELESAI',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ============================================================
  // TAB: PESANAN (update status + input resi)
  // ============================================================
  Future<void> _showEditOrderDialog(Map<String, dynamic> order) async {
    final result = await showOrderUpdateDialog(context, order);
    if (!mounted || result == null || result.isEmpty) return;

    final orderId = order['id']?.toString() ?? '';
    final idx = _allOrders.indexWhere((o) => o['id']?.toString() == orderId);
    if (idx != -1) {
      _allOrders[idx] = Map<String, dynamic>.from(_allOrders[idx])
        ..addAll(result);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pesanan berhasil diperbarui'),
        backgroundColor: AppColors.success,
      ),
    );
    setState(() {});
  }

  Widget _buildOrderManagementTab() {
    final filtered = _allOrders.where((o) {
      final id = o['id']?.toString().toLowerCase() ?? '';
      final status = o['status']?.toString().toLowerCase() ?? '';
      final resi = o['tracking_number']?.toString().toLowerCase() ?? '';
      final channel = o['channel']?.toString().toLowerCase() ?? 'online';
      final q = _manageOrderSearchQuery.toLowerCase();
      final matchesSearch =
          q.isEmpty || id.contains(q) || status.contains(q) || resi.contains(q);
      final matchesChannel =
          _manageOrderChannelFilter == 'all' ||
          channel == _manageOrderChannelFilter;
      return matchesSearch && matchesChannel;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari Order ID, status, atau resi...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _manageOrderSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _manageOrderSearchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
            onChanged: (val) => setState(() => _manageOrderSearchQuery = val),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Semua Saluran'),
                selected: _manageOrderChannelFilter == 'all',
                onSelected: (_) =>
                    setState(() => _manageOrderChannelFilter = 'all'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.language, size: 14),
                label: const Text('Online App'),
                selected: _manageOrderChannelFilter == 'online',
                onSelected: (_) =>
                    setState(() => _manageOrderChannelFilter = 'online'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.point_of_sale, size: 14),
                label: const Text('POS Kasir (In-Store)'),
                selected: _manageOrderChannelFilter == 'pos',
                onSelected: (_) =>
                    setState(() => _manageOrderChannelFilter = 'pos'),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada pesanan yang sesuai',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCashierData,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      final status =
                          order['status']?.toString() ?? 'processing';
                      final channel =
                          order['channel']?.toString().toLowerCase() ??
                          'online';
                      final isPos = channel == 'pos';
                      final cashierId = order['cashier_id']?.toString();
                      final resi = order['tracking_number']?.toString() ?? '';
                      final courier = order['courier']?.toString() ?? '';

                      final statusColor = status == 'delivered'
                          ? AppColors.success
                          : status == 'shipped'
                          ? AppColors.accent
                          : status == 'cancelled'
                          ? AppColors.error
                          : AppColors.warning;

                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isPos ? Icons.point_of_sale : Icons.receipt,
                            color: isPos ? AppColors.accent : statusColor,
                          ),
                          title: Text(
                            'Order: ${order['id'] ?? '-'}',
                            style: AppTextStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total: Rp ${_formatNumber(order['total_price'])}  •  Metode: ${order['payment_method'] ?? '-'}',
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    label: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: statusColor,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Chip(
                                    avatar: Icon(
                                      isPos ? Icons.store : Icons.language,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      isPos ? 'POS KASIR' : 'ONLINE',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: isPos
                                        ? const Color(0xFF8B5CF6)
                                        : AppColors.primary,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (cashierId != null && cashierId.isNotEmpty)
                                    Chip(
                                      label: Text(
                                        'Kasir: ${cashierId.length > 8 ? cashierId.substring(0, 8) : cashierId}',
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (resi.isNotEmpty)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.local_shipping,
                                        size: 12,
                                      ),
                                      label: Text(
                                        'Resi: $resi${courier.isNotEmpty ? ' ($courier)' : ''}',
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Update pesanan',
                            onPressed: () => _showEditOrderDialog(order),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ============================================================
  // TAB 4: CEK STOK BARANG
  // ============================================================
  Widget _buildStockTab() {
    final lowStock = _products.where((p) => _parseInt(p['stock']) < 5).length;
    final outOfStock = _products
        .where((p) => _parseInt(p['stock']) == 0)
        .length;

    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStockStat(
                'Total Produk',
                '${_products.length}',
                AppColors.primary,
              ),
              _buildStockStat(
                'Stok Rendah (<5)',
                '$lowStock',
                AppColors.warning,
              ),
              _buildStockStat('Stok Habis (0)', '$outOfStock', AppColors.error),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final p = _products[index];
              final stock = _parseInt(p['stock']);
              final price = _parseDouble(p['price']);

              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  title: Text(
                    p['name']?.toString() ?? '-',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Brand: ${p['brand'] ?? '-'} • Rp ${_formatNumber(price)}',
                    style: AppTextStyles.caption,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stock > 5
                          ? AppColors.success.withValues(alpha: 0.15)
                          : (stock > 0
                                ? AppColors.warning.withValues(alpha: 0.15)
                                : AppColors.error.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Stok: $stock',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: stock > 5
                            ? AppColors.success
                            : (stock > 0 ? AppColors.warning : AppColors.error),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _editProduct({ProductModel? product}) async {
    final editedProduct = await showDialog<ProductModel>(
      context: context,
      builder: (_) => ProductEditorDialog(product: product),
    );
    if (editedProduct == null || !mounted) return;

    try {
      final provider = context.read<ProductProvider>();
      if (product == null) {
        await provider.addProduct(editedProduct);
      } else {
        await provider.updateProduct(editedProduct);
        final oldImage = product.images.isNotEmpty
            ? product.images.first
            : null;
        final newImage = editedProduct.images.isNotEmpty
            ? editedProduct.images.first
            : null;
        if (oldImage != newImage) {
          try {
            await ProductImageStorageService.deleteProductImage(oldImage);
          } catch (error) {
            debugPrint('Old product image cleanup failed: $error');
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product == null
                ? 'Produk berhasil ditambahkan.'
                : 'Produk berhasil diperbarui.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadCashierData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produk gagal disimpan: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text('Produk "${product.name}" akan dihapus dari katalog.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<ProductProvider>().deleteProduct(product.id);
      if (product.images.isNotEmpty) {
        try {
          await ProductImageStorageService.deleteProductImage(
            product.images.first,
          );
        } catch (error) {
          debugPrint('Product image cleanup failed: $error');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produk berhasil dihapus.')));
      await _loadCashierData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produk gagal dihapus: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildProductManagementTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _editProduct(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk + Foto'),
            ),
          ),
        ),
        Expanded(
          child: _managedProducts.isEmpty
              ? const Center(child: Text('Belum ada produk dari database.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _managedProducts.length,
                  itemBuilder: (context, index) {
                    final product = ProductModel.fromMap(
                      _managedProducts[index],
                    );
                    return Card(
                      child: ListTile(
                        leading: SizedBox(
                          width: 48,
                          height: 48,
                          child: product.images.isEmpty
                              ? const Icon(Icons.image_outlined)
                              : Image.network(
                                  product.images.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.brand} • Rp ${_formatNumber(product.price)} • Stok ${product.stock}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Edit produk/foto',
                              onPressed: () => _editProduct(product: product),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Hapus produk',
                              onPressed: () => _deleteProduct(product),
                              icon: Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStockStat(String title, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(title, style: AppTextStyles.caption),
      ],
    );
  }
}

/// Menampilkan gambar produk POS dengan mencoba beberapa URL kandidat
/// secara berurutan sampai ada yang berhasil dimuat.
class _PosImageChain extends StatelessWidget {
  final List<String> urls;
  final int index;

  const _PosImageChain({required this.urls, this.index = 0});

  Widget _placeholder() => Container(
    color: Colors.grey.withValues(alpha: 0.12),
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, color: Colors.grey),
  );

  @override
  Widget build(BuildContext context) {
    if (index >= urls.length) return _placeholder();
    final url = urls[index];
    final next = _PosImageChain(urls: urls, index: index + 1);
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => next,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) => next,
    );
  }
}
