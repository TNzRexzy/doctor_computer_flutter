import 'package:image_picker/image_picker.dart';
import 'package:doctor_computer/core/utils/image_helper.dart';
import 'package:doctor_computer/widgets/common/app_image_view.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/review_provider.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/models/flash_sale_model.dart';
import 'package:doctor_computer/data/models/review_model.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  final supabase = Supabase.instance.client;

  String _productSearchQuery = '';
  final String _productCategoryFilter = 'all';
  String _orderSearchQuery = '';
  String _userSearchQuery = '';

  Timer? _flashSaleTicker;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    final isAdmin = user?.role == UserRole.admin;
    _tabController = TabController(
      length: isAdmin ? 6 : 4,
      vsync: this,
    );
    _loadData();

    _flashSaleTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _flashSaleTicker?.cancel();
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

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return 'Berakhir';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = d.inDays;
    final hours = twoDigits(d.inHours.remainder(24));
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (days > 0) return '$days hari $hours:$minutes:$seconds';
    return '$hours:$minutes:$seconds';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().currentUser;
      final isAdmin = user?.role == UserRole.admin;

      // Products - merge Supabase + ProductProvider (includes locally cached & newly added products)
      final productsRes = await supabase.from('products').select();
      final Map<String, Map<String, dynamic>> productMap = {};
      for (final p in productsRes) {
        final id = p['id']?.toString() ?? '';
        if (id.isNotEmpty) productMap[id] = Map<String, dynamic>.from(p);
      }
      if (mounted) {
        final providerProducts = context.read<ProductProvider>().allProducts;
        for (final p in providerProducts) {
          if (!productMap.containsKey(p.id)) {
            productMap[p.id] = p.toMap();
          }
        }
      }
      _products = productMap.values.toList();

      // Orders - merge Supabase + OrderProvider
      final ordersRes = await supabase.from('orders').select().order('order_date', ascending: false);
      final Map<String, Map<String, dynamic>> orderMap = {};
      for (final o in ordersRes) {
        final id = o['id']?.toString() ?? '';
        if (id.isNotEmpty) orderMap[id] = Map<String, dynamic>.from(o);
      }
      if (mounted) {
        final providerOrders = context.read<OrderProvider>().orders;
        for (final o in providerOrders) {
          if (!orderMap.containsKey(o.id)) {
            orderMap[o.id] = o.toMap();
          }
        }
      }
      _orders = orderMap.values.toList();

      // Apply locally cached order status overrides
      try {
        final prefs = await SharedPreferences.getInstance();
        final overridesJson = prefs.getString('admin_order_status_overrides');
        if (overridesJson != null && overridesJson.isNotEmpty) {
          final Map<String, dynamic> overrides = jsonDecode(overridesJson);
          for (int i = 0; i < _orders.length; i++) {
            final oid = _orders[i]['id']?.toString() ?? '';
            if (overrides.containsKey(oid)) {
              _orders[i] = Map<String, dynamic>.from(_orders[i]);
              _orders[i]['status'] = overrides[oid].toString();
            }
          }
        }
      } catch (e) {
        debugPrint('Error applying order overrides: $e');
      }

      // Users - admin only
      if (isAdmin) {
        final usersRes = await supabase.from('users').select();
        _users = List<Map<String, dynamic>>.from(usersRes);

        // Apply locally cached role overrides
        try {
          final prefs = await SharedPreferences.getInstance();
          final overridesJson = prefs.getString('admin_managed_user_roles');
          if (overridesJson != null && overridesJson.isNotEmpty) {
            final Map<String, dynamic> overrides = jsonDecode(overridesJson);
            for (int i = 0; i < _users.length; i++) {
              final uid = _users[i]['id']?.toString() ?? '';
              if (overrides.containsKey(uid)) {
                final override = overrides[uid] as Map<String, dynamic>;
                _users[i] = Map<String, dynamic>.from(_users[i])
                  ..addAll(override);
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading user overrides: $e');
        }
      }
    } catch (e) {
      debugPrint('Admin load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final user = context.read<AuthProvider>().currentUser;
    final isAdmin = user?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Dashboard Admin' : 'Dashboard Kasir'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: [
            const Tab(icon: Icon(Icons.inventory_2), text: 'Produk'),
            const Tab(icon: Icon(Icons.local_fire_department), text: 'Flash Sale'),
            const Tab(icon: Icon(Icons.receipt_long), text: 'Pesanan'),
            const Tab(icon: Icon(Icons.star_rate), text: 'Ulasan'),
            if (isAdmin) const Tab(icon: Icon(Icons.people), text: 'Pengguna'),
            if (isAdmin) const Tab(icon: Icon(Icons.analytics), text: 'Statistik'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(),
                _buildFlashSaleTab(),
                _buildOrdersTab(),
                _buildReviewsTab(),
                if (isAdmin) _buildUsersTab(),
                if (isAdmin) _buildStatsTab(),
              ],
            ),
    );
  }

  // ============================================================
  // TAB 1: PRODUCTS TAB
  // ============================================================
  Widget _buildProductsTab() {
    final filtered = _products.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final brand = p['brand']?.toString().toLowerCase() ?? '';
      final cat = p['category_id']?.toString().toLowerCase() ?? '';
      final matchesQuery = _productSearchQuery.isEmpty ||
          name.contains(_productSearchQuery.toLowerCase()) ||
          brand.contains(_productSearchQuery.toLowerCase());
      final matchesCat = _productCategoryFilter == 'all' || cat == _productCategoryFilter;
      return matchesQuery && matchesCat;
    }).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari produk berdasarkan nama atau brand...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _productSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _productSearchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (val) => setState(() => _productSearchQuery = val),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('Total: ${filtered.length} produk', style: AppTextStyles.caption),
                  const Spacer(),
                  if (context.read<ProductProvider>().runningFlashSales.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: Icon(Icons.local_fire_department, size: 16, color: AppColors.error),
                      label: Text('Ke Tab Flash Sale', style: TextStyle(color: AppColors.error, fontSize: 12)),
                      onPressed: () => _tabController.animateTo(1),
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
                          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          Text('Tidak ada produk yang cocok', style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final isOnSale = context.read<ProductProvider>().isInFlashSale(product['id']?.toString() ?? '');
                        final price = _parseDouble(product['price']);
                        final origPrice = _parseDouble(product['original_price']);
                        final stock = _parseInt(product['stock']);

                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isOnSale
                                    ? AppColors.error.withValues(alpha: 0.12)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isOnSale ? Icons.local_fire_department : Icons.inventory_2,
                                color: isOnSale ? AppColors.error : AppColors.textSecondary,
                              ),
                            ),
                            title: Text(
                              product['name']?.toString() ?? '-',
                              style: AppTextStyles.titleSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Brand: ${product['brand'] ?? '-'}', style: AppTextStyles.caption),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text('Stok: $stock',
                                        style: TextStyle(
                                            color: stock < 5 ? AppColors.error : AppColors.success,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Harga: Rp ${_formatNumber(price)}',
                                        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isOnSale) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'FLASH SALE',
                                          style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (origPrice > price) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          'Rp ${_formatNumber(origPrice)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textTertiary,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: AppColors.primary),
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _showEditProductDialog(product);
                                    break;
                                  case 'flash_sale':
                                    _openFlashSaleConfigSheet(productId: product['id']?.toString());
                                    break;
                                  case 'delete':
                                    _confirmDeleteProduct(product);
                                    break;
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit Produk')),
                                PopupMenuItem(
                                  value: 'flash_sale',
                                  child: Text(isOnSale ? 'Atur Flash Sale' : 'Jadikan Flash Sale'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus Produk', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Produk'),
      ),
    );
  }

  // ============================================================
  // TAB 2: FLASH SALE (admin & kasir) - data dari tabel flash_sales
  // ============================================================
  String _fmtDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _buildFlashSaleTab() {
    final productProvider = context.watch<ProductProvider>();
    final sales = productProvider.flashSales;
    final runningCount = productProvider.runningFlashSales.length;
    final remaining = productProvider.flashSaleRemainingTime;
    final hasRunning = runningCount > 0 && remaining > Duration.zero;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.error,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Flash Sale', style: TextStyle(color: Colors.white)),
        onPressed: () => _openFlashSaleConfigSheet(),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<ProductProvider>().reloadFlashSales(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            GlassCard(
              child: Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: hasRunning ? AppColors.error : AppColors.textTertiary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasRunning ? '$runningCount produk sedang Flash Sale' : 'Tidak ada Flash Sale berjalan',
                          style: AppTextStyles.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasRunning
                              ? 'Promo terdekat berakhir dalam ${_formatDuration(remaining)}'
                              : 'Pilih produk dari katalog lalu atur harga, kuota, dan jadwalnya.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Daftar Flash Sale (${sales.length})', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            if (sales.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.local_fire_department_outlined, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: 8),
                    Text('Belum ada Flash Sale', style: AppTextStyles.bodyMedium),
                  ],
                ),
              )
            else
              ...sales.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildFlashSaleCard(s, productProvider),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashSaleCard(FlashSaleModel sale, ProductProvider provider) {
    final now = DateTime.now();
    final status = sale.statusAt(now);
    final product = provider.getProductById(sale.productId);

    late final String statusLabel;
    late final Color statusColor;
    switch (status) {
      case FlashSaleStatus.running:
        statusLabel = 'BERJALAN';
        statusColor = AppColors.success;
        break;
      case FlashSaleStatus.scheduled:
        statusLabel = 'TERJADWAL';
        statusColor = AppColors.warning;
        break;
      case FlashSaleStatus.soldOut:
        statusLabel = 'HABIS';
        statusColor = AppColors.error;
        break;
      case FlashSaleStatus.ended:
        statusLabel = 'BERAKHIR';
        statusColor = AppColors.textTertiary;
        break;
      case FlashSaleStatus.inactive:
        statusLabel = 'DIHENTIKAN';
        statusColor = AppColors.textTertiary;
        break;
    }
    final canEdit = status == FlashSaleStatus.running ||
        status == FlashSaleStatus.scheduled ||
        status == FlashSaleStatus.soldOut;
    final progress = sale.flashStock > 0 ? sale.soldCount / sale.flashStock : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product?.name ?? 'Produk (${sale.productId})',
                  style: AppTextStyles.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(4)),
                child: Text('-${sale.discountPercent.round()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text('Rp ${_formatNumber(sale.flashPrice)}',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Rp ${_formatNumber(sale.originalPrice)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        decoration: TextDecoration.lineThrough)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              color: AppColors.error,
              backgroundColor: AppColors.error.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 4),
          Text('Terjual ${sale.soldCount} / ${sale.flashStock} (sisa kuota ${sale.stockLeft})',
              style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            '${_fmtDateTime(sale.startsAt)} - ${_fmtDateTime(sale.endsAt)}'
            '${status == FlashSaleStatus.running ? '  •  sisa ${_formatDuration(sale.endsAt.difference(now))}' : ''}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canEdit)
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Ubah'),
                  onPressed: () => _openFlashSaleConfigSheet(sale: sale),
                ),
              if (canEdit)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.warning),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text('Akhiri'),
                  onPressed: () => _confirmFlashAction(
                    title: 'Akhiri Flash Sale',
                    message: 'Hentikan flash sale "${product?.name ?? sale.productId}" sekarang? Harga kembali normal.',
                    confirmLabel: 'Akhiri',
                    action: () => context.read<ProductProvider>().endFlashSale(sale.id),
                    successMessage: 'Flash Sale diakhiri',
                  ),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Hapus'),
                onPressed: () => _confirmFlashAction(
                  title: 'Hapus Flash Sale',
                  message: 'Hapus data flash sale ini secara permanen?',
                  confirmLabel: 'Hapus',
                  action: () => context.read<ProductProvider>().deleteFlashSale(sale.id),
                  successMessage: 'Flash Sale dihapus',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFlashAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<String?> Function() action,
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final error = await action();
    messenger.showSnackBar(SnackBar(content: Text(error ?? successMessage)));
    if (error == null && mounted) _loadData();
  }

  // Buka form atur flash sale: baru (opsional productId terpilih) atau ubah [sale].
  void _openFlashSaleConfigSheet({FlashSaleModel? sale, String? productId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _FlashSaleSheetWidget(
        sale: sale,
        initialProductId: productId,
        onSaved: () {
          if (mounted) _loadData();
        },
      ),
    );
  }

  // ============================================================
  // TAB 3: ORDERS TAB
  // ============================================================
  Widget _buildOrdersTab() {
    final filtered = _orders.where((o) {
      final id = o['id']?.toString().toLowerCase() ?? '';
      final status = o['status']?.toString().toLowerCase() ?? '';
      return _orderSearchQuery.isEmpty ||
          id.contains(_orderSearchQuery.toLowerCase()) ||
          status.contains(_orderSearchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari Order ID atau status...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _orderSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _orderSearchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (val) => setState(() => _orderSearchQuery = val),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      Text('Belum ada pesanan yang sesuai', style: AppTextStyles.bodyMedium),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      final status = order['status']?.toString() ?? 'processing';
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
                          leading: Icon(Icons.receipt, color: statusColor),
                          title: Text(
                            'Order: ${order['id'] ?? '-'}',
                            style: AppTextStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total: Rp ${_formatNumber(order['total_price'])}'),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(fontSize: 10, color: Colors.white),
                                    ),
                                    backgroundColor: statusColor,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditOrderStatusDialog(order),
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

  void _showEditOrderStatusDialog(Map<String, dynamic> order) {
    String selectedStatus = order['status']?.toString() ?? 'processing';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update Status Pesanan', style: AppTextStyles.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Order ID: ${order['id']}', style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
              ...['processing', 'shipped', 'delivered', 'cancelled'].map(
                (status) => RadioListTile<String>(
                  value: status,
                  groupValue: selectedStatus,
                  title: Text(status.toUpperCase()),
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedStatus = val);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final orderId = order['id']?.toString() ?? '';

                OrderStatus newStatus = OrderStatus.processing;
                for (final s in OrderStatus.values) {
                  if (s.name.toLowerCase() == selectedStatus.toLowerCase()) {
                    newStatus = s;
                    break;
                  }
                }

                // Update via OrderProvider (saves to memory, local cache, and Supabase)
                await context.read<OrderProvider>().updateOrderStatus(orderId, newStatus);

                // Update local list
                final idx = _orders.indexWhere((o) => o['id']?.toString() == orderId);
                if (idx != -1) {
                  _orders[idx] = Map<String, dynamic>.from(_orders[idx]);
                  _orders[idx]['status'] = selectedStatus;
                }

                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Status pesanan berhasil diperbarui')),
                );
                if (mounted) setState(() {});
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB 4: REVIEWS TAB
  // ============================================================
  Widget _buildReviewsTab() {
    final reviewProvider = context.watch<ReviewProvider>();
    final reviews = reviewProvider.allReviews;

    if (reviewProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('Belum ada ulasan', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await reviewProvider.refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: reviews.length,
        itemBuilder: (context, index) {
          final review = reviews[index];
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      radius: 18,
                      child: Text(
                        review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(review.userName, style: AppTextStyles.titleSmall),
                          Text(
                            'Produk ID: ${review.productId}',
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(review.comment, style: AppTextStyles.bodyMedium),
                Text(
                  review.date.toString().substring(0, 10),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                ),

                if (review.reply != null && review.reply!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.store, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Respon Penjual${review.replyRole != null ? ' - ${review.replyRole == 'admin' ? 'Admin' : 'Kasir'}' : ''}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(review.reply!, style: AppTextStyles.bodySmall),
                        if (review.replyDate != null)
                          Text(
                            review.replyDate!.toString().substring(0, 10),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showReplyReviewDialog(review),
                    icon: Icon(
                      review.reply != null ? Icons.edit : Icons.reply,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      review.reply != null ? 'Edit Balasan' : 'Balas Ulasan',
                      style: TextStyle(color: AppColors.primary, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReplyReviewDialog(ReviewModel review) {
    final replyC = TextEditingController(text: review.reply ?? '');
    final user = context.read<AuthProvider>().currentUser;
    final replierRole = user?.role == UserRole.admin ? 'admin' : 'cashier';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Balas Ulasan', style: AppTextStyles.titleMedium),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName, style: AppTextStyles.titleSmall),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(review.comment, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Balasan Anda (${replierRole == 'admin' ? 'Admin' : 'Kasir'}):',
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 8),
              TextField(
                controller: replyC,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Tulis balasan untuk ulasan ini...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final replyText = replyC.text.trim();
              if (replyText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Balasan tidak boleh kosong')),
                );
                return;
              }

              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);

              final reviewProvider = context.read<ReviewProvider>();
              final success = await reviewProvider.replyToReview(
                reviewId: review.id,
                replyText: replyText,
                replierRole: replierRole,
              );

              nav.pop();
              messenger.showSnackBar(
                SnackBar(content: Text(success ? 'Balasan berhasil disimpan' : 'Gagal menyimpan balasan')),
              );
            },
            child: const Text('Kirim Balasan'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 5: USERS TAB (ADMIN ONLY)
  // ============================================================
  Widget _buildUsersTab() {
    final filtered = _users.where((u) {
      final name = u['full_name']?.toString().toLowerCase() ?? '';
      final email = u['email']?.toString().toLowerCase() ?? '';
      return _userSearchQuery.isEmpty ||
          name.contains(_userSearchQuery.toLowerCase()) ||
          email.contains(_userSearchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari pengguna berdasarkan nama atau email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _userSearchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (val) => setState(() => _userSearchQuery = val),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text('Tidak ada pengguna yang cocok', style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final u = filtered[index];
                      final tier = u['membership_tier']?.toString() ?? 'bronze';
                      final role = u['role']?.toString() ?? 'user';
                      final points = (u['points'] as num?)?.toInt() ?? 0;

                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              (u['full_name']?.toString() ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            u['full_name']?.toString() ?? '-',
                            style: AppTextStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['email']?.toString() ?? '-', style: AppTextStyles.caption),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(tier.toUpperCase(), style: const TextStyle(fontSize: 9)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 4),
                                  Chip(
                                    label: Text(
                                      role.toUpperCase(),
                                      style: const TextStyle(fontSize: 9, color: Colors.white),
                                    ),
                                    backgroundColor: role == 'admin'
                                        ? AppColors.error
                                        : role == 'cashier'
                                            ? AppColors.warning
                                            : AppColors.accent,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$points pts',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.edit, color: AppColors.primary),
                            onPressed: () => _showEditUserDialog(u),
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

  void _showEditUserDialog(Map<String, dynamic> userData) {
    final nameController =
        TextEditingController(text: userData['full_name']?.toString() ?? '');
    final pointsController =
        TextEditingController(text: (userData['points'] ?? 0).toString());
    String selectedRole = userData['role']?.toString() ?? 'user';
    String selectedTier = userData['membership_tier']?.toString() ?? 'bronze';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Hak Akses Pengguna', style: AppTextStyles.titleMedium),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${userData['email']}', style: AppTextStyles.caption),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Poin / EXP',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Role Akses:', style: AppTextStyles.bodySmall),
                ...['user', 'cashier', 'admin'].map((r) => RadioListTile<String>(
                      value: r,
                      groupValue: selectedRole,
                      title: Text(r.toUpperCase()),
                      dense: true,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    )),
                const SizedBox(height: 8),
                Text('Tier Membership:', style: AppTextStyles.bodySmall),
                ...['bronze', 'silver', 'gold', 'platinum'].map(
                  (t) => RadioListTile<String>(
                    value: t,
                    groupValue: selectedTier,
                    title: Text(t.toUpperCase()),
                    dense: true,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedTier = val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final userId = userData['id']?.toString() ?? '';
                final updatePayload = {
                  'full_name': nameController.text.trim(),
                  'points': int.tryParse(pointsController.text) ?? 0,
                  'role': selectedRole,
                  'membership_tier': selectedTier,
                };

                // 1. Update in-memory list immediately
                final idx = _users.indexWhere((u) => u['id'] == userId);
                if (idx != -1) {
                  _users[idx] = Map<String, dynamic>.from(_users[idx])..addAll(updatePayload);
                }

                // 2. Cache role/tier override in SharedPreferences
                try {
                  final prefs = await SharedPreferences.getInstance();
                  Map<String, dynamic> overrides = {};
                  final existingJson = prefs.getString('admin_managed_user_roles');
                  if (existingJson != null && existingJson.isNotEmpty) {
                    overrides = Map<String, dynamic>.from(jsonDecode(existingJson));
                  }
                  overrides[userId] = {
                    'role': selectedRole,
                    'membership_tier': selectedTier,
                    'full_name': nameController.text.trim(),
                    'points': int.tryParse(pointsController.text) ?? 0,
                  };
                  await prefs.setString('admin_managed_user_roles', jsonEncode(overrides));
                } catch (e) {
                  debugPrint('Error caching user role override: $e');
                }

                // 3. Update blockchain wallet points & tier
                if (!ctx.mounted) return;
                try {
                  MemberTier targetTier = MemberTier.bronze;
                  for (final t in MemberTier.values) {
                    if (t.name.toLowerCase() == selectedTier.toLowerCase()) {
                      targetTier = t;
                      break;
                    }
                  }
                  final newExp = int.tryParse(pointsController.text) ?? 0;
                  final targetName = nameController.text.trim().isNotEmpty
                      ? nameController.text.trim()
                      : (userData['full_name']?.toString() ?? 'Pengguna');
                  await context.read<BlockchainProvider>().adminSetUserPoints(
                    userId: userId,
                    userName: targetName,
                    newExp: newExp,
                    newTier: targetTier,
                    adminNote: 'Penyesuaian oleh Admin (${context.read<AuthProvider>().currentUser?.fullName ?? "Admin"})',
                  );
                } catch (e) {
                  debugPrint('Error syncing blockchain points in admin dialog: $e');
                }

                // 4. Attempt Supabase update
                bool supabaseSuccess = false;
                try {
                  await supabase.from('users').update(updatePayload).eq('id', userId);
                  supabaseSuccess = true;
                } catch (e) {
                  debugPrint('Supabase user update notice: $e');
                }

                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(supabaseSuccess
                        ? 'Pengguna berhasil diupdate'
                        : 'Hak akses disimpan secara lokal'),
                  ),
                );
                if (mounted) setState(() {});
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB 6: STATS TAB (ADMIN ONLY)
  // ============================================================
  Widget _buildStatsTab() {
    final totalProducts = _products.length;
    final totalOrders = _orders.length;
    final totalUsers = _users.length;
    final lowStockProducts =
        _products.where((p) => (_parseInt(p['stock'])) < 5).length;
    final flashSaleCount =
        context.read<ProductProvider>().runningFlashSales.length;
    final totalRevenue = _orders.fold<double>(
        0, (sum, o) => sum + (_parseDouble(o['total_price'])));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            children: [
              if (isWide) ...[
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Total Produk', '$totalProducts', Icons.inventory, AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Total Pesanan', '$totalOrders', Icons.receipt, AppColors.accent)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Total Pengguna', '$totalUsers', Icons.people, AppColors.success)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Stok Rendah', '$lowStockProducts', Icons.warning, AppColors.error)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Flash Sale', '$flashSaleCount', Icons.local_fire_department, AppColors.warning)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Ulasan', '${context.read<ReviewProvider>().allReviews.length}', Icons.star_rate, Colors.amber)),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Total Produk', '$totalProducts', Icons.inventory, AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Total Pesanan', '$totalOrders', Icons.receipt, AppColors.accent)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Total Pengguna', '$totalUsers', Icons.people, AppColors.success)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Stok Rendah', '$lowStockProducts', Icons.warning, AppColors.error)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Flash Sale', '$flashSaleCount', Icons.local_fire_department, AppColors.warning)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Ulasan', '${context.read<ReviewProvider>().allReviews.length}', Icons.star_rate, Colors.amber)),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Pendapatan', style: AppTextStyles.titleSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Rp ${_formatNumber(totalRevenue)}',
                      style: AppTextStyles.heading2.copyWith(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Produk Stok Rendah (< 5)', style: AppTextStyles.titleSmall),
                    const SizedBox(height: 8),
                    ..._products
                        .where((p) => (_parseInt(p['stock'])) < 5)
                        .map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.warning, size: 16, color: AppColors.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p['name']?.toString() ?? '-',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    'Stok: ${p['stock'] ?? 0}',
                                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.heading3.copyWith(color: color)),
          Text(title, style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ============================================================
  // PRODUCT ADD DIALOG
  // ============================================================
  void _showAddProductDialog() {
    final nameC = TextEditingController();
    final brandC = TextEditingController();
    final priceC = TextEditingController();
    final stockC = TextEditingController(text: '10');
    final descC = TextEditingController();
    final imageUrlC = TextEditingController();
    String selectedCategory = 'laptop';

    final categoryOptions = [
      'laptop', 'desktop', 'monitor', 'keyboard', 'mouse',
      'headset', 'storage', 'networking', 'cpu', 'gpu',
      'motherboard', 'ram', 'case', 'cooler', 'psu',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Tambah Produk Baru', style: AppTextStyles.titleMedium),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: 'Nama Produk',
                      hintText: 'Contoh: ASUS ROG Strix G16',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: brandC,
                    decoration: const InputDecoration(
                      labelText: 'Brand',
                      hintText: 'Contoh: ASUS',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: categoryOptions.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.toUpperCase()),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Jual (Rp)',
                      hintText: 'Contoh: 15000000',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stockC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descC,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imageUrlC,
                          decoration: const InputDecoration(
                            labelText: 'Gambar Produk (URL / File)',
                            hintText: 'Pilih file atau isi URL gambar',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        icon: const Icon(Icons.attach_file),
                        tooltip: 'Pilih File Gambar dari Galeri',
                        onPressed: () async {
                          final base64Img = await AppImageHelper.pickImageAsBase64(
                            source: ImageSource.gallery,
                          );
                          if (base64Img != null) {
                            setDialogState(() {
                              imageUrlC.text = base64Img;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        style: IconButton.styleFrom(backgroundColor: AppColors.primaryDark, foregroundColor: Colors.white),
                        icon: const Icon(Icons.camera_alt),
                        tooltip: 'Ambil Foto Produk dengan Kamera',
                        onPressed: () async {
                          final base64Img = await AppImageHelper.pickImageAsBase64(
                            source: ImageSource.camera,
                          );
                          if (base64Img != null) {
                            setDialogState(() {
                              imageUrlC.text = base64Img;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (imageUrlC.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AppImageView(
                          imageUrl: imageUrlC.text,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final name = nameC.text.trim();
                final brand = brandC.text.trim();
                final price = _parseDouble(priceC.text.trim());
                final stock = _parseInt(stockC.text.trim());

                if (name.isEmpty || brand.isEmpty || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama, Brand, dan Harga wajib diisi')),
                  );
                  return;
                }

                final productId = 'admin-${DateTime.now().millisecondsSinceEpoch}';
                final newProduct = ProductModel(
                  id: productId,
                  name: name,
                  description: descC.text.trim().isEmpty ? name : descC.text.trim(),
                  descriptionId: descC.text.trim().isEmpty ? name : descC.text.trim(),
                  price: price,
                  categoryId: selectedCategory,
                  brand: brand,
                  images: imageUrlC.text.trim().isNotEmpty ? [imageUrlC.text.trim()] : [],
                  specs: {},
                  rating: 0,
                  reviewCount: 0,
                  stock: stock,
                  isNew: true,
                  isOnSale: false,
                );

                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final productProvider = context.read<ProductProvider>();

                await productProvider.addProduct(newProduct);
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Produk berhasil ditambahkan')),
                );
                if (mounted) _loadData();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    final stockController =
        TextEditingController(text: (product['stock'] ?? 0).toString());
    final priceController =
        TextEditingController(text: (product['price'] ?? 0).toString());
    final nameController =
        TextEditingController(text: product['name']?.toString() ?? '');
    final brandController =
        TextEditingController(text: product['brand']?.toString() ?? '');
    final descController =
        TextEditingController(text: product['description']?.toString() ?? '');
    String initialImg = '';
    final rawImgs = product['image_url'];
    if (rawImgs is List && rawImgs.isNotEmpty) {
      initialImg = rawImgs.first.toString();
    } else if (rawImgs != null) {
      initialImg = rawImgs.toString();
    }
    final imageController = TextEditingController(text: initialImg);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: Text('Edit Produk', style: AppTextStyles.titleMedium),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Produk', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: brandController,
                  decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga (Rp)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Deskripsi', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imageController,
                        decoration: const InputDecoration(
                          labelText: 'Gambar Produk (URL / File)',
                          hintText: 'Pilih file atau isi URL gambar',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      icon: const Icon(Icons.attach_file),
                      tooltip: 'Pilih File Gambar dari Galeri',
                      onPressed: () async {
                        final base64Img = await AppImageHelper.pickImageAsBase64(
                          source: ImageSource.gallery,
                        );
                        if (base64Img != null) {
                          setDialogState(() {
                            imageController.text = base64Img;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: AppColors.primaryDark, foregroundColor: Colors.white),
                      icon: const Icon(Icons.camera_alt),
                      tooltip: 'Ambil Foto Produk dengan Kamera',
                      onPressed: () async {
                        final base64Img = await AppImageHelper.pickImageAsBase64(
                          source: ImageSource.camera,
                        );
                        if (base64Img != null) {
                          setDialogState(() {
                            imageController.text = base64Img;
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (imageController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 80,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppImageView(
                        imageUrl: imageController.text,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final productProvider = context.read<ProductProvider>();

              try {
                final imgVal = imageController.text.trim();
                final updateData = {
                  'name': nameController.text.trim(),
                  'brand': brandController.text.trim(),
                  'price': _parseDouble(priceController.text.trim()),
                  'stock': _parseInt(stockController.text.trim()),
                  'description': descController.text.trim(),
                  if (imgVal.isNotEmpty) 'image_url': [imgVal],
                };

                await supabase.from('products').update(updateData).eq('id', product['id']);

                try {
                  final existing = productProvider.getProductById(product['id']?.toString() ?? '');
                  if (existing != null) {
                    await productProvider.updateProduct(existing.withoutFlash().copyWith(
                      name: updateData['name']?.toString(),
                      brand: updateData['brand']?.toString(),
                      price: (updateData['price'] as num?)?.toDouble(),
                      stock: (updateData['stock'] as num?)?.toInt(),
                      description: updateData['description']?.toString(),
                      descriptionId: updateData['description']?.toString(),
                      images: imgVal.isNotEmpty ? [imgVal] : null,
                    ));
                  }
                } catch (_) {}

                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Produk berhasil diupdate')),
                );
                if (mounted) _loadData();
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Gagal: $e')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
    );
  }

  void _confirmDeleteProduct(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Produk', style: AppTextStyles.titleMedium),
        content: Text('Apakah Anda yakin ingin menghapus "${product['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final productProvider = context.read<ProductProvider>();
                await productProvider.deleteProduct(product['id']?.toString() ?? '');
                try {
                  await supabase.from('products').delete().eq('id', product['id']);
                } catch (_) {}
              } catch (e) {
                debugPrint('Delete product error: $e');
              }

              nav.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Produk berhasil dihapus')),
              );
              if (mounted) _loadData();
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FLASH SALE FORM (admin & kasir)
// Pilih produk dari katalog (tabel products) -> atur harga, kuota,
// jadwal -> disimpan ke tabel flash_sales.
// ============================================================
class _FlashSaleSheetWidget extends StatefulWidget {
  final FlashSaleModel? sale; // non-null = mode ubah
  final String? initialProductId;
  final VoidCallback onSaved;

  const _FlashSaleSheetWidget({
    required this.sale,
    required this.initialProductId,
    required this.onSaved,
  });

  @override
  State<_FlashSaleSheetWidget> createState() => _FlashSaleSheetWidgetState();
}

class _FlashSaleSheetWidgetState extends State<_FlashSaleSheetWidget> {
  ProductModel? _selectedProduct;
  final TextEditingController _searchC = TextEditingController();
  final TextEditingController _salePriceC = TextEditingController();
  final TextEditingController _stockC = TextEditingController();
  int _discountPct = 20;
  late DateTime _startsAt;
  late DateTime _endsAt;
  bool _isInit = false;
  bool _isSaving = false;

  bool get _isEdit => widget.sale != null;

  @override
  void dispose() {
    _searchC.dispose();
    _salePriceC.dispose();
    _stockC.dispose();
    super.dispose();
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    final n = number is num ? number : num.tryParse(number.toString()) ?? 0;
    return n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) return;
    _isInit = true;
    final provider = context.read<ProductProvider>();
    final now = DateTime.now();
    _startsAt = now;
    _endsAt = now.add(const Duration(hours: 24));

    final sale = widget.sale;
    if (sale != null) {
      _selectedProduct = provider.getProductById(sale.productId);
      _startsAt = sale.startsAt;
      _endsAt = sale.endsAt;
      _salePriceC.text = sale.flashPrice.toStringAsFixed(0);
      _stockC.text = sale.flashStock.toString();
      _syncDiscountFromPrice();
    } else if (widget.initialProductId != null) {
      _selectedProduct = provider.getProductById(widget.initialProductId!);
      _applyDiscount();
    }
  }

  double get _normalPrice => _selectedProduct?.basePrice ?? 0;

  void _selectProduct(ProductModel p) {
    setState(() {
      _selectedProduct = p;
      _stockC.text = (p.stock < 10 ? p.stock : 10).toString();
      _applyDiscount();
    });
  }

  // slider -> harga
  void _applyDiscount() {
    if (_selectedProduct == null) return;
    _salePriceC.text = (_normalPrice * (1 - _discountPct / 100)).round().toString();
  }

  // harga -> slider
  void _syncDiscountFromPrice() {
    final price = _parseDouble(_salePriceC.text);
    if (_normalPrice > 0 && price > 0 && price < _normalPrice) {
      _discountPct = ((1 - price / _normalPrice) * 100).round().clamp(5, 80);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final product = _selectedProduct;
    if (product == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final provider = context.read<ProductProvider>();

    setState(() => _isSaving = true);
    final error = await provider.saveFlashSale(
      id: widget.sale?.id,
      productId: product.id,
      flashPrice: _parseDouble(_salePriceC.text),
      flashStock: int.tryParse(_stockC.text.trim()) ?? 0,
      startsAt: _startsAt,
      endsAt: _endsAt,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_isEdit ? 'Flash Sale diperbarui' : 'Produk masuk ke Flash Sale'),
    ));
    widget.onSaved();
  }

  Widget _durationChip(String label, Duration d) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () => setState(() => _endsAt = _startsAt.add(d)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final query = _searchC.text.trim().toLowerCase();
    // Produk dari katalog yang belum punya flash sale aktif/terjadwal & masih ada stok
    final candidates = provider.allProducts.where((p) {
      if (p.stock <= 0) return false;
      if (provider.flashSaleForProduct(p.id) != null) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          p.brand.toLowerCase().contains(query) ||
          (p.sku?.toLowerCase().contains(query) ?? false);
    }).toList();

    final product = _selectedProduct;
    final salePrice = _parseDouble(_salePriceC.text);
    final liveDiscount = (_normalPrice > 0 && salePrice > 0 && salePrice < _normalPrice)
        ? ((1 - salePrice / _normalPrice) * 100).round()
        : 0;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.local_fire_department, color: AppColors.error, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product == null
                            ? 'Pilih Produk untuk Flash Sale'
                            : (_isEdit ? 'Ubah Flash Sale' : 'Atur Flash Sale'),
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(),
                if (product == null) ...[
                  Text('Pilih produk yang sudah ada di katalog toko:', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchC,
                    decoration: InputDecoration(
                      hintText: 'Cari nama, brand, atau SKU...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 260,
                    child: candidates.isEmpty
                        ? const Center(child: Text('Tidak ada produk yang tersedia'))
                        : ListView.builder(
                            itemCount: candidates.length,
                            itemBuilder: (ctx, i) {
                              final p = candidates[i];
                              return ListTile(
                                dense: true,
                                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${p.brand} • Rp ${_formatNumber(p.basePrice)} • Stok: ${p.stock}'),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => _selectProduct(p),
                                  child: const Text('Pilih', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                              );
                            },
                          ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name,
                                  style: AppTextStyles.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(
                                '${product.brand} • Harga normal: Rp ${_formatNumber(_normalPrice)} • Stok: ${product.stock}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        if (!_isEdit)
                          TextButton(
                            onPressed: () => setState(() => _selectedProduct = null),
                            child: const Text('Ganti'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Diskon Flash Sale (%)', style: AppTextStyles.bodySmall),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _discountPct.toDouble(),
                          min: 5,
                          max: 80,
                          divisions: 15,
                          label: '$_discountPct%',
                          activeColor: AppColors.error,
                          onChanged: (val) => setState(() {
                            _discountPct = val.round();
                            _applyDiscount();
                          }),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(6)),
                        child: Text('-${liveDiscount > 0 ? liveDiscount : _discountPct}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _salePriceC,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Harga Flash Sale (Rp)',
                      helperText: 'Harga normal Rp ${_formatNumber(_normalPrice)} tidak diubah',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(_syncDiscountFromPrice),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stockC,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Kuota Flash Sale (unit)',
                      helperText: 'Maksimal ${product.stock} (stok produk)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Jadwal', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: Text('Mulai\n${_fmt(_startsAt)}', style: const TextStyle(fontSize: 11)),
                          onPressed: () async {
                            final d = await _pickDateTime(_startsAt);
                            if (d != null) {
                              setState(() {
                                final len = _endsAt.difference(_startsAt);
                                _startsAt = d;
                                if (!_endsAt.isAfter(_startsAt)) _endsAt = _startsAt.add(len.isNegative ? const Duration(hours: 24) : len);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.stop, size: 16),
                          label: Text('Selesai\n${_fmt(_endsAt)}', style: const TextStyle(fontSize: 11)),
                          onPressed: () async {
                            final d = await _pickDateTime(_endsAt);
                            if (d != null) setState(() => _endsAt = d);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _durationChip('1 jam', const Duration(hours: 1)),
                      _durationChip('6 jam', const Duration(hours: 6)),
                      _durationChip('24 jam', const Duration(hours: 24)),
                      _durationChip('3 hari', const Duration(days: 3)),
                      _durationChip('7 hari', const Duration(days: 7)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_isEdit ? 'Simpan Perubahan' : 'Aktifkan Flash Sale'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
