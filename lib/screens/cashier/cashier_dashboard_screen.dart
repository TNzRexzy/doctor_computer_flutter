import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';

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
  List<Map<String, dynamic>> _posOrders = [];

  // POS Cart: Map of productId -> quantity
  final Map<String, int> _cart = {};

  String _productSearchQuery = '';
  String _selectedCategory = 'all';
  String _orderSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCashierData();
  }

  @override
  void dispose() {
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
    return n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );
  }

  String _getCashierId() {
    final user = context.read<AuthProvider>().currentUser;
    return user?.id ?? 'cashier-dc-001';
  }

  String _getCashierName() {
    final user = context.read<AuthProvider>().currentUser;
    return user?.fullName ?? 'Kasir';
  }

  Future<void> _loadCashierData() async {
    setState(() => _isLoading = true);
    final cashierId = _getCashierId();

    try {
      // 1. Fetch active shift for this cashier
      try {
        final shiftRes = await supabase
            .from('cashier_shifts')
            .select()
            .eq('cashier_id', cashierId)
            .eq('status', 'open')
            .maybeSingle();
        _currentShift = shiftRes != null ? Map<String, dynamic>.from(shiftRes) : null;
      } catch (e) {
        debugPrint('Notice loading active shift from Supabase: $e');
        _currentShift = null;
      }

      // Check local cache if DB was null or errored
      if (_currentShift == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final localJson = prefs.getString('local_cashier_shift_$cashierId');
          if (localJson != null && localJson.isNotEmpty) {
            final decoded = jsonDecode(localJson);
            if (decoded is Map<String, dynamic> && decoded['status'] == 'open') {
              _currentShift = decoded;
            }
          }
        } catch (_) {}
      }

      // 2. Fetch shift history
      try {
        final historyRes = await supabase
            .from('cashier_shifts')
            .select()
            .eq('cashier_id', cashierId)
            .order('opened_at', ascending: false)
            .limit(15);
        _shiftHistory = List<Map<String, dynamic>>.from(historyRes);
      } catch (e) {
        debugPrint('Notice loading shift history: $e');
      }

      // 3. Fetch products (merge Supabase + ProductProvider)
      try {
        final productsRes = await supabase.from('products').select();
        final Map<String, Map<String, dynamic>> pMap = {};
        for (final p in productsRes) {
          final id = p['id']?.toString() ?? '';
          if (id.isNotEmpty) pMap[id] = Map<String, dynamic>.from(p);
        }
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

      // 4. Fetch POS orders
      try {
        final ordersRes = await supabase
            .from('orders')
            .select()
            .eq('channel', 'pos')
            .order('order_date', ascending: false)
            .limit(30);
        _posOrders = List<Map<String, dynamic>>.from(ordersRes);
      } catch (e) {
        debugPrint('Notice loading POS orders: $e');
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
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final cash = double.tryParse(cashCtrl.text.replaceAll('.', '')) ?? 0;
                      setDialogState(() => isSubmitting = true);
                      final cashierId = _getCashierId();

                      Map<String, dynamic>? newShiftData;
                      bool isLocal = false;

                      try {
                        final res = await supabase.from('cashier_shifts').insert({
                          'cashier_id': cashierId,
                          'opening_cash': cash,
                          'notes': notesCtrl.text.trim(),
                          'status': 'open',
                        }).select().single();
                        newShiftData = Map<String, dynamic>.from(res);
                      } catch (e) {
                        debugPrint('Supabase cashier_shifts insert error (fallback local): $e');
                        isLocal = true;
                        newShiftData = {
                          'id': 'shift-${DateTime.now().millisecondsSinceEpoch}',
                          'cashier_id': cashierId,
                          'opening_cash': cash,
                          'total_sales': 0.0,
                          'total_orders': 0,
                          'notes': notesCtrl.text.trim(),
                          'status': 'open',
                          'opened_at': DateTime.now().toIso8601String(),
                        };
                      }

                      // Persist to SharedPreferences
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('local_cashier_shift_$cashierId', jsonEncode(newShiftData));
                      } catch (_) {}

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(isLocal
                                ? 'Shift kasir dibuka (mode sesi lokal)!'
                                : 'Shift kasir berhasil dibuka di server!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        setState(() {
                          _currentShift = newShiftData;
                        });
                        _loadCashierData();
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

    final closingCashCtrl = TextEditingController(text: expectedCash.toStringAsFixed(0));
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final counted = double.tryParse(closingCashCtrl.text.replaceAll('.', '')) ?? 0;
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
                        _buildSummaryRow('Modal Kas Awal:', 'Rp ${_formatNumber(openingCash)}'),
                        const SizedBox(height: 4),
                        _buildSummaryRow('Total Penjualan Shift:', 'Rp ${_formatNumber(totalSales)}'),
                        const SizedBox(height: 4),
                        _buildSummaryRow('Total Transaksi:', '$totalOrders pesanan'),
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
                      Text('Selisih Kas (Variance):', style: AppTextStyles.caption),
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
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final cashierId = _getCashierId();
                        final shiftId = _currentShift!['id']?.toString() ?? '';
                        setDialogState(() => isSubmitting = true);

                        try {
                          await supabase.from('cashier_shifts').update({
                            'status': 'closed',
                            'closing_cash': counted,
                            'closed_at': DateTime.now().toIso8601String(),
                            'notes': notesCtrl.text.trim(),
                          }).eq('id', shiftId);
                        } catch (e) {
                          debugPrint('Supabase close shift notice: $e');
                        }

                        // Clear local cache
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('local_cashier_shift_$cashierId');
                        } catch (_) {}

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Shift kasir berhasil ditutup.'),
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

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
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
          content: const Text('Buka shift kasir terlebih dahulu untuk transaksi!'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok tidak mencukupi!')),
      );
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
    final tenderedCtrl = TextEditingController(text: subtotal.toStringAsFixed(0));
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final tendered = double.tryParse(tenderedCtrl.text.replaceAll('.', '')) ?? 0;
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
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('Total Pembayaran', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${_formatNumber(subtotal)}',
                          style: AppTextStyles.heading2.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Metode Pembayaran:', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPaymentOption('Cash', paymentMethod, (m) => setDialogState(() => paymentMethod = m)),
                      const SizedBox(width: 8),
                      _buildPaymentOption('QRIS', paymentMethod, (m) => setDialogState(() => paymentMethod = m)),
                      const SizedBox(width: 8),
                      _buildPaymentOption('Debit BCA', paymentMethod, (m) => setDialogState(() => paymentMethod = m)),
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
                        _buildQuickAmountChip('Pas', subtotal, tenderedCtrl, () => setDialogState(() {})),
                        _buildQuickAmountChip('50rb', 50000, tenderedCtrl, () => setDialogState(() {})),
                        _buildQuickAmountChip('100rb', 100000, tenderedCtrl, () => setDialogState(() {})),
                        _buildQuickAmountChip('200rb', 200000, tenderedCtrl, () => setDialogState(() {})),
                        _buildQuickAmountChip('500rb', 500000, tenderedCtrl, () => setDialogState(() {})),
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
                            color: change >= 0 ? AppColors.success : AppColors.error,
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
                            paymentMethod == 'QRIS' ? Icons.qr_code : Icons.credit_card,
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
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: (!canPay || isSubmitting)
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        await _processCheckout(
                          dialogCtx: ctx,
                          paymentMethod: paymentMethod,
                          subtotal: subtotal,
                          tendered: tendered,
                          change: change,
                        );
                      },
                child: Text(isSubmitting ? 'Memproses...' : 'Selesaikan Transaksi'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentOption(String method, String selected, ValueChanged<String> onSelect) {
    final isSelected = method == selected;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(method),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
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
      String label, double amount, TextEditingController ctrl, VoidCallback onUpdate) {
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

  Future<void> _processCheckout({
    required BuildContext dialogCtx,
    required String paymentMethod,
    required double subtotal,
    required double tendered,
    required double change,
  }) async {
    final cashierId = _getCashierId();
    final cashierName = _getCashierName();

    final List<Map<String, dynamic>> itemsPayload = [];
    final List<Map<String, dynamic>> receiptItems = [];

    for (final entry in _cart.entries) {
      final prod = _products.firstWhere(
        (p) => p['id']?.toString() == entry.key,
        orElse: () => {},
      );
      if (prod.isNotEmpty) {
        final price = _parseDouble(prod['price']);
        itemsPayload.add({
          'product_id': entry.key,
          'quantity': entry.value,
          'unit_price': price,
        });
        receiptItems.add({
          'name': prod['name'] ?? 'Produk',
          'quantity': entry.value,
          'unit_price': price,
          'subtotal': price * entry.value,
        });
      }
    }

    String generatedOrderId = 'POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    try {
      // 1. Call create_pos_order RPC
      final rpcRes = await supabase.rpc('create_pos_order', params: {
        'p_cashier_id': cashierId,
        'p_total_price': subtotal,
        'p_payment_method': paymentMethod,
        'p_items': itemsPayload,
      });

      if (rpcRes != null) {
        generatedOrderId = rpcRes.toString();
      }
    } catch (e) {
      debugPrint('create_pos_order RPC fallback notice: $e');

      // Fallback: manual insert to orders if RPC fails
      try {
        await supabase.from('orders').insert({
          'id': generatedOrderId,
          'cashier_id': cashierId,
          'total_price': subtotal,
          'payment_method': paymentMethod,
          'status': 'delivered',
          'channel': 'pos',
          'shipping_address': 'Ambil di Toko (POS Kasir)',
          'items_summary': receiptItems,
        });

        // Deduct product stock locally and in DB
        for (final item in itemsPayload) {
          final pid = item['product_id'];
          final qty = item['quantity'] as int;
          try {
            final prod = _products.firstWhere((p) => p['id'] == pid);
            final currentStock = _parseInt(prod['stock']);
            final newStock = (currentStock - qty).clamp(0, 99999);
            await supabase.from('products').update({'stock': newStock}).eq('id', pid);
          } catch (_) {}
        }
      } catch (fallbackErr) {
        debugPrint('Fallback order insert error: $fallbackErr');
      }
    }

    if (dialogCtx.mounted) Navigator.pop(dialogCtx);

    // Update local shift accumulator if shift is active
    if (_currentShift != null) {
      final curSales = _parseDouble(_currentShift!['total_sales']) + subtotal;
      final curOrders = (_currentShift!['total_orders'] ?? 0) + 1;
      _currentShift!['total_sales'] = curSales;
      _currentShift!['total_orders'] = curOrders;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_cashier_shift_$cashierId', jsonEncode(_currentShift));
      } catch (_) {}
    }

    // Clear cart and refresh
    setState(() {
      _cart.clear();
    });
    _loadCashierData();

    // Show Digital Receipt
    if (mounted) {
      _showReceiptDialog(
        orderId: generatedOrderId,
        cashierName: cashierName,
        items: receiptItems,
        totalPrice: subtotal,
        paymentMethod: paymentMethod,
        tendered: tendered,
        change: change >= 0 ? change : 0,
      );
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
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text('Sistem Kasir & POS Omnichannel', style: AppTextStyles.caption),
                      Text('Jl. Elektronik Komputer No. 10', style: AppTextStyles.caption),
                      const Divider(height: 20),

                      _buildSummaryRow('No. Nota:', orderId),
                      _buildSummaryRow('Tanggal:', DateTime.now().toString().split('.').first),
                      _buildSummaryRow('Kasir:', cashierName),
                      const Divider(height: 20),

                      ...items.map((it) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it['name']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),

                      const Divider(height: 20),
                      _buildSummaryRow('TOTAL:', 'Rp ${_formatNumber(totalPrice)}', isBold: true),
                      _buildSummaryRow('Metode:', paymentMethod),
                      if (paymentMethod == 'Cash') ...[
                        _buildSummaryRow('Tunai:', 'Rp ${_formatNumber(tendered)}'),
                        _buildSummaryRow('Kembalian:', 'Rp ${_formatNumber(change)}', color: AppColors.success),
                      ],
                      const Divider(height: 20),
                      Text(
                        'Terima Kasih Atas Kunjungan Anda!',
                        style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
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
                const SnackBar(content: Text('Perintah cetak dikirim ke printer POS!')),
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
            const Text('Dashboard Kasir & POS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen ? Colors.green.shade600 : Colors.red.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(isOpen ? Icons.check_circle : Icons.lock, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      isOpen ? 'SHIFT OPEN' : 'SHIFT CLOSED',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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
            const Tab(icon: Icon(Icons.receipt_long), text: 'Riwayat Transaksi'),
            const Tab(icon: Icon(Icons.inventory_2), text: 'Cek Stok'),
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
                _buildStockTab(),
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
      final matchesQuery = _productSearchQuery.isEmpty ||
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _showOpenShiftDialog,
                  child: const Text('Buka Shift', style: TextStyle(fontSize: 11)),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              _buildCategoryChip('laptops', 'Laptop'),
              _buildCategoryChip('pc_parts', 'PC Parts'),
              _buildCategoryChip('monitors', 'Monitor'),
              _buildCategoryChip('accessories', 'Aksesoris'),
              _buildCategoryChip('audio', 'Audio'),
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
                            ? const BorderSide(color: Color(0xFF8B5CF6), width: 2)
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: stock > 5
                                          ? AppColors.success.withValues(alpha: 0.15)
                                          : (stock > 0
                                              ? AppColors.warning.withValues(alpha: 0.15)
                                              : AppColors.error.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      stock > 0 ? 'Stok: $stock' : 'Habis',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: stock > 5
                                            ? AppColors.success
                                            : (stock > 0 ? AppColors.warning : AppColors.error),
                                      ),
                                    ),
                                  ),
                                  if (inCartQty > 0)
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      child: Text(
                                        '$inCartQty',
                                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                p['name']?.toString() ?? '-',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    color: const Color(0xFF8B5CF6),
                                    onPressed: stock > 0 ? () => _addToCart(p) : null,
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
                              icon: const Icon(Icons.remove_circle_outline, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _removeFromCart(entry.key),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _addToCart(prod),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Rp ${_formatNumber(price * entry.value)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                      Text('$totalItems Item di Keranjang', style: AppTextStyles.caption),
                      Text(
                        'Rp ${_formatNumber(subtotal)}',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_cart.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _cart.clear()),
                          child: Text('Reset', style: TextStyle(color: AppColors.error)),
                        ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.payment, size: 18, color: Colors.white),
                        label: const Text('Bayar POS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildCategoryChip(String catId, String label) {
    final isSelected = _selectedCategory == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
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
                    Text('Status Shift Saat Ini', style: AppTextStyles.titleMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isOpen ? AppColors.success : Colors.grey).withValues(alpha: 0.15),
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
                  _buildSummaryRow('ID Shift:', _currentShift!['id']?.toString() ?? '-'),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Waktu Dibuka:', _currentShift!['opened_at']?.toString().split('.').first ?? '-'),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Modal Kas Awal:', 'Rp ${_formatNumber(_currentShift!['opening_cash'])}'),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Total Penjualan:', 'Rp ${_formatNumber(_currentShift!['total_sales'])}', isBold: true, color: AppColors.success),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Jumlah Transaksi:', '${_currentShift!['total_orders'] ?? 0} pesanan'),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Catatan:', _currentShift!['notes']?.toString() ?? '-'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (isShiftOpen ? AppColors.success : Colors.grey).withValues(alpha: 0.15),
                    child: Icon(
                      isShiftOpen ? Icons.lock_open : Icons.lock,
                      color: isShiftOpen ? AppColors.success : Colors.grey,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Buka: $openedAt',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Penjualan: Rp ${_formatNumber(sales)} • $orders pesanan',
                    style: AppTextStyles.caption,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isShiftOpen ? AppColors.success : Colors.grey).withValues(alpha: 0.15),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (val) => setState(() => _orderSearchQuery = val),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('Total: ${filtered.length} transaksi POS', style: AppTextStyles.caption),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6D28D9).withValues(alpha: 0.15),
                          child: const Icon(Icons.receipt, color: Color(0xFF6D28D9), size: 20),
                        ),
                        title: Text(
                          order['id']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SELESAI',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success),
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
  // TAB 4: CEK STOK BARANG
  // ============================================================
  Widget _buildStockTab() {
    final lowStock = _products.where((p) => _parseInt(p['stock']) < 5).length;
    final outOfStock = _products.where((p) => _parseInt(p['stock']) == 0).length;

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
              _buildStockStat('Total Produk', '${_products.length}', AppColors.primary),
              _buildStockStat('Stok Rendah (<5)', '$lowStock', AppColors.warning),
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Brand: ${p['brand'] ?? '-'} • Rp ${_formatNumber(price)}',
                    style: AppTextStyles.caption,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildStockStat(String title, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: AppTextStyles.caption),
      ],
    );
  }
}
