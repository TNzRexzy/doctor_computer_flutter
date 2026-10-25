import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/review_provider.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/models/review_model.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/product_image_picker.dart';
import 'package:doctor_computer/services/product_image_storage_service.dart';
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
  List<Map<String, dynamic>> _shifts = [];
  bool _isLoading = true;
  final supabase = Supabase.instance.client;

  String _productSearchQuery = '';
  final String _productCategoryFilter = 'all';
  String _orderSearchQuery = '';
  String _orderChannelFilter = 'all'; // 'all', 'online', 'pos'
  String _userSearchQuery = '';

  Timer? _flashSaleTicker;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    final isAdmin = user?.role == UserRole.admin;
    _tabController = TabController(length: isAdmin ? 6 : 4, vsync: this);
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
    return n
        .toStringAsFixed(0)
        .replaceAllMapped(
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

      // Products - merge Supabase + ProductProvider (isolated so one failure doesn't abort others)
      try {
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
      } catch (e) {
        debugPrint('Notice loading products: $e');
        if (mounted) {
          final providerProducts = context.read<ProductProvider>().allProducts;
          _products = providerProducts.map((p) => p.toMap()).toList();
        }
      }

      // Orders - merge Supabase + OrderProvider (try order_date, fallback created_at)
      try {
        List<dynamic> ordersRes;
        try {
          ordersRes = await supabase
              .from('orders')
              .select()
              .order('order_date', ascending: false);
        } catch (_) {
          ordersRes = await supabase
              .from('orders')
              .select()
              .order('created_at', ascending: false);
        }
        final Map<String, Map<String, dynamic>> orderMap = {};
        for (final o in ordersRes) {
          final id = o['id']?.toString() ?? '';
          if (id.isNotEmpty) orderMap[id] = Map<String, dynamic>.from(o);
        }
        _orders = orderMap.values.toList();
      } catch (e) {
        debugPrint('Notice loading orders: $e');
        _orders = [];
      }

      // Users - admin only
      if (isAdmin) {
        final usersRes = await supabase.from('users').select();
        _users = List<Map<String, dynamic>>.from(usersRes);

        // Cashier shifts - admin monitoring
        try {
          final shiftsRes = await supabase
              .from('cashier_shifts')
              .select()
              .order('opened_at', ascending: false)
              .limit(20);
          _shifts = List<Map<String, dynamic>>.from(shiftsRes);
        } catch (e) {
          debugPrint('Notice loading cashier shifts: $e');
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
            const Tab(
              icon: Icon(Icons.local_fire_department),
              text: 'Flash Sale',
            ),
            const Tab(icon: Icon(Icons.receipt_long), text: 'Pesanan'),
            const Tab(icon: Icon(Icons.star_rate), text: 'Ulasan'),
            if (isAdmin) const Tab(icon: Icon(Icons.people), text: 'Pengguna'),
            if (isAdmin)
              const Tab(icon: Icon(Icons.analytics), text: 'Statistik'),
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
      final matchesQuery =
          _productSearchQuery.isEmpty ||
          name.contains(_productSearchQuery.toLowerCase()) ||
          brand.contains(_productSearchQuery.toLowerCase());
      final matchesCat =
          _productCategoryFilter == 'all' || cat == _productCategoryFilter;
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
                          onPressed: () =>
                              setState(() => _productSearchQuery = ''),
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
                onChanged: (val) => setState(() => _productSearchQuery = val),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Total: ${filtered.length} produk',
                    style: AppTextStyles.caption,
                  ),
                  const Spacer(),
                  if (_products.any((p) => p['is_on_sale'] == true))
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: AppColors.error,
                      ),
                      label: Text(
                        'Ke Tab Flash Sale',
                        style: TextStyle(color: AppColors.error, fontSize: 12),
                      ),
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
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada produk yang cocok',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final isOnSale = product['is_on_sale'] == true;
                        final price = _parseDouble(product['price']);
                        final origPrice = _parseDouble(
                          product['original_price'],
                        );
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
                                isOnSale
                                    ? Icons.local_fire_department
                                    : Icons.inventory_2,
                                color: isOnSale
                                    ? AppColors.error
                                    : AppColors.textSecondary,
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
                                Text(
                                  'Brand: ${product['brand'] ?? '-'}',
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      'Stok: $stock',
                                      style: TextStyle(
                                        color: stock < 5
                                            ? AppColors.error
                                            : AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Harga: Rp ${_formatNumber(price)}',
                                        style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'FLASH SALE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (origPrice > price) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          'Rp ${_formatNumber(origPrice)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textTertiary,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: AppColors.primary,
                              ),
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _showEditProductDialog(product);
                                    break;
                                  case 'flash_sale':
                                    _openFlashSaleConfigSheet(product);
                                    break;
                                  case 'delete':
                                    _confirmDeleteProduct(product);
                                    break;
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit Produk'),
                                ),
                                PopupMenuItem(
                                  value: 'flash_sale',
                                  child: Text(
                                    isOnSale
                                        ? 'Atur / Hapus Flash Sale'
                                        : 'Aktifkan Flash Sale',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Hapus Produk',
                                    style: TextStyle(color: Colors.red),
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
  // TAB 2: FLASH SALE REAL-TIME MENU (DEDICATED)
  // ============================================================
  Widget _buildFlashSaleTab() {
    final productProvider = context.watch<ProductProvider>();
    final flashSaleEndTime = productProvider.flashSaleEndTime;
    final isFlashSaleActive = productProvider.isFlashSaleActive;
    final remaining = productProvider.flashSaleRemainingTime;
    final flashProducts = productProvider.allProducts
        .where((p) => p.isOnSale)
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await productProvider.reloadData();
          await _loadData();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real-time Countdown Controller Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: AppColors.error,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kontrol Waktu Flash Sale Realtime',
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isFlashSaleActive && remaining > Duration.zero
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isFlashSaleActive && remaining > Duration.zero
                                  ? AppColors.success
                                  : AppColors.textTertiary,
                            ),
                          ),
                          child: Text(
                            isFlashSaleActive && remaining > Duration.zero
                                ? 'AKTIF'
                                : 'NONAKTIF',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  isFlashSaleActive && remaining > Duration.zero
                                  ? AppColors.success
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      title: const Text('Status Flash Sale Global'),
                      subtitle: const Text(
                        'Mengaktifkan banner promo dan harga coret di Beranda & Katalog',
                      ),
                      value: isFlashSaleActive,
                      activeColor: AppColors.error,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                        final ok = await productProvider.setFlashSaleActive(val);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Flash Sale ${val ? "diaktifkan" : "dinonaktifkan"}'
                                    : 'Gagal menyimpan ke database. Pastikan ada produk flash sale & policy flash_sales sudah dipasang.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // Countdown Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'SISA WAKTU FLASH SALE:',
                            style: AppTextStyles.caption.copyWith(
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDuration(remaining),
                            style: AppTextStyles.heading2.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target Berakhir: ${flashSaleEndTime.day}/${flashSaleEndTime.month}/${flashSaleEndTime.year} - ${flashSaleEndTime.hour.toString().padLeft(2, '0')}:${flashSaleEndTime.minute.toString().padLeft(2, '0')} WIB',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quick duration presets
                    Text(
                      'Perpanjang Waktu Cepat:',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickTimeChip(
                          context,
                          '+2 Jam',
                          const Duration(hours: 2),
                        ),
                        _buildQuickTimeChip(
                          context,
                          '+6 Jam',
                          const Duration(hours: 6),
                        ),
                        _buildQuickTimeChip(
                          context,
                          '+12 Jam',
                          const Duration(hours: 12),
                        ),
                        _buildQuickTimeChip(
                          context,
                          '+24 Jam',
                          const Duration(hours: 24),
                        ),
                        _buildQuickTimeChip(
                          context,
                          '+3 Hari',
                          const Duration(days: 3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Custom Date Time Picker button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('Atur Tanggal & Jam Selesai Kustom'),
                        onPressed: _pickCustomFlashSaleDateTime,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Active Flash Sale Products Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Produk Flash Sale (${flashProducts.length})',
                    style: AppTextStyles.titleMedium,
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tambah Produk'),
                    onPressed: () => _openFlashSaleConfigSheet(null),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (flashProducts.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_fire_department_outlined,
                          size: 56,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada produk dalam Flash Sale',
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Klik "Tambah Produk" untuk memasukkan barang promosi',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 650;
                    if (isTablet) {
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.2,
                            ),
                        itemCount: flashProducts.length,
                        itemBuilder: (context, index) {
                          return _buildFlashProductCard(flashProducts[index]);
                        },
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: flashProducts.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildFlashProductCard(flashProducts[index]),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Promo Flash Sale'),
        onPressed: () => _openFlashSaleConfigSheet(null),
      ),
    );
  }

  Widget _buildQuickTimeChip(
    BuildContext context,
    String label,
    Duration duration,
  ) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      avatar: const Icon(Icons.timer_outlined, size: 14),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final productProvider = context.read<ProductProvider>();
        final newEnd = DateTime.now().add(duration);
        final ok = await productProvider.updateFlashSaleTime(newEnd);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Waktu Flash Sale diperpanjang $label'
                  : 'Gagal menyimpan waktu ke database. Pastikan ada produk flash sale & policy flash_sales sudah dipasang.',
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCustomFlashSaleDateTime() async {
    final messenger = ScaffoldMessenger.of(context);
    final productProvider = context.read<ProductProvider>();
    final now = DateTime.now();
    final currentEnd = productProvider.flashSaleEndTime;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentEnd.isAfter(now)
          ? currentEnd
          : now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'Pilih Tanggal Selesai Flash Sale',
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentEnd.hour, minute: currentEnd.minute),
      helpText: 'Pilih Jam Selesai Flash Sale',
    );

    if (pickedTime == null || !mounted) return;

    final finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (finalDateTime.isBefore(DateTime.now())) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Waktu selesai harus lebih besar dari waktu saat ini'),
        ),
      );
      return;
    }

    final ok = await productProvider.updateFlashSaleTime(finalDateTime);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Waktu Flash Sale berhasil diperbarui secara realtime'
              : 'Gagal menyimpan waktu ke database. Pastikan ada produk flash sale & policy flash_sales sudah dipasang.',
        ),
      ),
    );
  }

  Widget _buildFlashProductCard(ProductModel product) {
    final discount = product.discountPercentage.round();

    return GlassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: product.images.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.images.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.inventory_2, color: AppColors.error),
                  ),
                )
              : Icon(Icons.inventory_2, color: AppColors.error),
        ),
        title: Text(
          product.name,
          style: AppTextStyles.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-$discount%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rp ${_formatNumber(product.price)}',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (product.originalPrice != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Rp ${_formatNumber(product.originalPrice)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        decoration: TextDecoration.lineThrough,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text('Stok: ${product.stock}', style: AppTextStyles.caption),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.primary, size: 20),
              tooltip: 'Ubah Diskon',
              onPressed: () => _openFlashSaleConfigSheet(product.toMap()),
            ),
            IconButton(
              icon: Icon(Icons.close, color: AppColors.error, size: 20),
              tooltip: 'Hapus dari Flash Sale',
              onPressed: () => _removeProductFromFlashSale(product),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeProductFromFlashSale(ProductModel product) async {
    final messenger = ScaffoldMessenger.of(context);
    final productProvider = context.read<ProductProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluarkan dari Flash Sale'),
        content: Text('Kembalikan "${product.name}" ke harga normal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluarkan'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await productProvider.toggleFlashSale(product.id, false);

    try {
      await supabase
          .from('products')
          .update({
            'is_on_sale': false,
            'price': product.originalPrice ?? product.price,
            'original_price': null,
          })
          .eq('id', product.id);
    } catch (e) {
      debugPrint('Supabase revert flash sale notice: $e');
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Produk dikeluarkan dari Flash Sale')),
    );
    if (mounted) _loadData();
  }

  // ============================================================
  // FLASH SALE BOTTOM SHEET (BUG FIX: NO WHITE SCREEN, ROBUST CONSTRAINTS)
  // ============================================================
  void _openFlashSaleConfigSheet(Map<String, dynamic>? initialProduct) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _FlashSaleSheetWidget(
        initialProduct: initialProduct,
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
      final channel = o['channel']?.toString().toLowerCase() ?? 'online';
      final matchesSearch =
          _orderSearchQuery.isEmpty ||
          id.contains(_orderSearchQuery.toLowerCase()) ||
          status.contains(_orderSearchQuery.toLowerCase());
      final matchesChannel =
          _orderChannelFilter == 'all' || channel == _orderChannelFilter;
      return matchesSearch && matchesChannel;
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
        // Filter Channel (Semua, Online, POS Kasir)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Semua Saluran'),
                selected: _orderChannelFilter == 'all',
                onSelected: (_) => setState(() => _orderChannelFilter = 'all'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.language, size: 14),
                label: const Text('Online App'),
                selected: _orderChannelFilter == 'online',
                onSelected: (_) =>
                    setState(() => _orderChannelFilter = 'online'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.point_of_sale, size: 14),
                label: const Text('POS Kasir (In-Store)'),
                selected: _orderChannelFilter == 'pos',
                onSelected: (_) => setState(() => _orderChannelFilter = 'pos'),
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
                  onRefresh: _loadData,
                  child: ListView.builder(
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
          title: Text(
            'Update Status Pesanan',
            style: AppTextStyles.titleMedium,
          ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
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

                final success = await context
                    .read<OrderProvider>()
                    .updateOrderStatus(orderId, newStatus);
                if (!ctx.mounted) return;
                if (!success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        context.read<OrderProvider>().errorMessage ??
                            'Status pesanan gagal diperbarui.',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                // Update local list
                final idx = _orders.indexWhere(
                  (o) => o['id']?.toString() == orderId,
                );
                if (idx != -1) {
                  _orders[idx] = Map<String, dynamic>.from(_orders[idx]);
                  _orders[idx]['status'] = selectedStatus;
                }

                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Status pesanan berhasil diperbarui'),
                  ),
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
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
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
                        review.userName.isNotEmpty
                            ? review.userName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.userName,
                            style: AppTextStyles.titleSmall,
                          ),
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
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),

                if (review.reply != null && review.reply!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.store,
                              size: 14,
                              color: AppColors.primary,
                            ),
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
              Text(
                'Balasan Anda (${replierRole == 'admin' ? 'Admin' : 'Kasir'}):',
                style: AppTextStyles.bodySmall,
              ),
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
                SnackBar(
                  content: Text(
                    success
                        ? 'Balasan berhasil disimpan'
                        : 'Gagal menyimpan balasan',
                  ),
                ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
            onChanged: (val) => setState(() => _userSearchQuery = val),
          ),
        ),
        // Action Bar: Counter & Button Provision Staff
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total ${filtered.length} Akun Terdaftar',
                  style: AppTextStyles.caption,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text(
                  'Tambah Staff (Kasir/Admin)',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _showProvisionStaffDialog,
              ),
            ],
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
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada pengguna yang cocok',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final u = filtered[index];
                      final tier = u['membership_tier']?.toString() ?? 'bronze';
                      final rawRole = u['role']?.toString() ?? 'client';
                      final role = rawRole == 'user' ? 'client' : rawRole;
                      final points = (u['points'] as num?)?.toInt() ?? 0;

                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: role == 'admin'
                                ? AppColors.error
                                : role == 'cashier'
                                ? AppColors.warning
                                : AppColors.primary,
                            child: Text(
                              (u['full_name']?.toString() ?? '?')[0]
                                  .toUpperCase(),
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
                              Text(
                                u['email']?.toString() ?? '-',
                                style: AppTextStyles.caption,
                              ),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      tier.toUpperCase(),
                                      style: const TextStyle(fontSize: 9),
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 4),
                                  Chip(
                                    label: Text(
                                      role.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: role == 'admin'
                                        ? AppColors.error
                                        : role == 'cashier'
                                        ? AppColors.warning
                                        : AppColors.primary,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$points pts',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.accent,
                                    ),
                                  ),
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

  void _showProvisionStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'cashier';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.badge, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Tambah Akun Staff Baru', style: AppTextStyles.titleMedium),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Akun staff dibuat melalui Edge Function terautentikasi dan role ditetapkan di server.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap Staff *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Login *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password Akun (min. 6 karakter) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Pilih Role Staff:', style: AppTextStyles.bodySmall),
                RadioListTile<String>(
                  value: 'cashier',
                  groupValue: selectedRole,
                  title: const Text('KASIR (Akses POS & Kasir)'),
                  dense: true,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
                RadioListTile<String>(
                  value: 'admin',
                  groupValue: selectedRole,
                  title: const Text('ADMINISTRATOR (Full Akses)'),
                  dense: true,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
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
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final pass = passwordCtrl.text;

                      if (name.isEmpty || email.isEmpty || pass.length < 12) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Lengkapi form (password min 12 karakter)!',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        final response = await supabase.functions.invoke(
                          'provision-staff',
                          body: {
                            'email': email,
                            'password': pass,
                            'full_name': name,
                            'role': selectedRole,
                          },
                        );
                        final res = response.data is Map
                            ? (response.data as Map)['id']
                            : null;
                        if (res == null) {
                          throw const FormatException(
                            'Respons provisioning tidak valid.',
                          );
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Staff $name ($selectedRole) berhasil dibuat! ID: $res',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          _loadData();
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal membuat staff: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: Text(isSubmitting ? 'Memproses...' : 'Simpan Staff'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> userData) {
    final nameController = TextEditingController(
      text: userData['full_name']?.toString() ?? '',
    );
    final pointsController = TextEditingController(
      text: (userData['points'] ?? 0).toString(),
    );
    final rawRole = userData['role']?.toString() ?? 'client';
    String selectedRole = rawRole == 'user' ? 'client' : rawRole;
    String selectedTier = userData['membership_tier']?.toString() ?? 'bronze';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Edit Hak Akses Pengguna',
            style: AppTextStyles.titleMedium,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email: ${userData['email']}',
                  style: AppTextStyles.caption,
                ),
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
                ...['client', 'cashier', 'admin'].map(
                  (r) => RadioListTile<String>(
                    value: r,
                    groupValue: selectedRole,
                    title: Text(
                      r == 'client'
                          ? 'CLIENT (Pelanggan App)'
                          : r == 'cashier'
                          ? 'CASHIER (Kasir POS)'
                          : 'ADMIN (Administrator)',
                    ),
                    dense: true,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final userId = userData['id']?.toString() ?? '';
                final fullName = nameController.text.trim();
                final points = int.tryParse(pointsController.text);
                if (userId.isEmpty ||
                    fullName.isEmpty ||
                    fullName.length > 100 ||
                    points == null ||
                    points < 0) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Periksa nama dan jumlah poin yang dimasukkan.',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                try {
                  final result = await supabase.rpc(
                    'admin_update_user',
                    params: {
                      'p_user_id': userId,
                      'p_full_name': fullName,
                      'p_points': points,
                      'p_role': selectedRole,
                      'p_membership_tier': selectedTier,
                    },
                  );
                  if (result is! Map) {
                    throw const FormatException(
                      'Respons admin_update_user tidak valid.',
                    );
                  }
                  if (!ctx.mounted) return;
                  final idx = _users.indexWhere((u) => u['id'] == userId);
                  if (idx != -1) {
                    _users[idx] = Map<String, dynamic>.from(result);
                  }
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Pengguna berhasil diupdate')),
                  );
                  if (mounted) {
                    setState(() {});
                    _loadData();
                  }
                } catch (e) {
                  debugPrint('admin_update_user failed: $e');
                  if (ctx.mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Gagal memperbarui pengguna: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
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
    final lowStockProducts = _products
        .where((p) => (_parseInt(p['stock'])) < 5)
        .length;
    final flashSaleCount = _products
        .where((p) => p['is_on_sale'] == true)
        .length;
    final totalRevenue = _orders.fold<double>(
      0,
      (sum, o) => sum + (_parseDouble(o['total_price'])),
    );

    // Omnichannel breakdown
    final onlineOrders = _orders
        .where((o) => (o['channel'] ?? 'online') == 'online')
        .toList();
    final posOrders = _orders.where((o) => o['channel'] == 'pos').toList();
    final onlineRevenue = onlineOrders.fold<double>(
      0,
      (sum, o) => sum + (_parseDouble(o['total_price'])),
    );
    final posRevenue = posOrders.fold<double>(
      0,
      (sum, o) => sum + (_parseDouble(o['total_price'])),
    );

    final openShifts = _shifts.where((s) => s['status'] == 'open').toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWide) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Produk',
                        '$totalProducts',
                        Icons.inventory,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Pesanan',
                        '$totalOrders',
                        Icons.receipt,
                        AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Pengguna',
                        '$totalUsers',
                        Icons.people,
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Stok Rendah',
                        '$lowStockProducts',
                        Icons.warning,
                        AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Flash Sale',
                        '$flashSaleCount',
                        Icons.local_fire_department,
                        AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Ulasan',
                        '${context.read<ReviewProvider>().allReviews.length}',
                        Icons.star_rate,
                        Colors.amber,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Produk',
                        '$totalProducts',
                        Icons.inventory,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Pesanan',
                        '$totalOrders',
                        Icons.receipt,
                        AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Pengguna',
                        '$totalUsers',
                        Icons.people,
                        AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Stok Rendah',
                        '$lowStockProducts',
                        Icons.warning,
                        AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Flash Sale',
                        '$flashSaleCount',
                        Icons.local_fire_department,
                        AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Ulasan',
                        '${context.read<ReviewProvider>().allReviews.length}',
                        Icons.star_rate,
                        Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Pendapatan & Omnichannel
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Pendapatan (Omnichannel)',
                          style: AppTextStyles.titleSmall,
                        ),
                        Icon(
                          Icons.monetization_on,
                          color: AppColors.accent,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rp ${_formatNumber(totalRevenue)}',
                      style: AppTextStyles.heading2.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Online (${onlineOrders.length} order)',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rp ${_formatNumber(onlineRevenue)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF8B5CF6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'POS Kasir (${posOrders.length} order)',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rp ${_formatNumber(posRevenue)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF8B5CF6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Monitoring Shift Kasir
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.point_of_sale,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Monitoring Shift Kasir',
                              style: AppTextStyles.titleSmall,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: openShifts.isNotEmpty
                                ? AppColors.success.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            openShifts.isNotEmpty
                                ? '${openShifts.length} Shift Terbuka'
                                : 'Semua Shift Tutup',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: openShifts.isNotEmpty
                                  ? AppColors.success
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_shifts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'Belum ada data shift kasir di sistem.',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      )
                    else
                      ..._shifts.take(5).map((shift) {
                        final isOpen = shift['status'] == 'open';
                        final cashier =
                            shift['users'] != null && shift['users'] is Map
                            ? (shift['users']['full_name'] ??
                                  shift['cashier_id'] ??
                                  '-')
                            : (shift['cashier_id'] ?? '-');
                        final openedAt = shift['opened_at'] != null
                            ? shift['opened_at'].toString().split('T').first
                            : '-';
                        final shiftSales = _parseDouble(shift['total_sales']);
                        final shiftOrders = shift['total_orders'] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOpen
                                  ? AppColors.success.withValues(alpha: 0.4)
                                  : Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isOpen
                                    ? AppColors.success.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.2),
                                child: Icon(
                                  isOpen ? Icons.lock_open : Icons.lock,
                                  size: 16,
                                  color: isOpen
                                      ? AppColors.success
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$cashier',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Buka: $openedAt  •  $shiftOrders pesanan',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rp ${_formatNumber(shiftSales)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isOpen ? AppColors.success : null,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (isOpen
                                                  ? AppColors.success
                                                  : Colors.grey)
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isOpen ? 'OPEN' : 'CLOSED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isOpen
                                            ? AppColors.success
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Produk Stok Rendah
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produk Stok Rendah (< 5)',
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ..._products
                        .where((p) => (_parseInt(p['stock'])) < 5)
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 16,
                                  color: AppColors.error,
                                ),
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
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.heading3.copyWith(color: color)),
          Text(
            title,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PRODUCT ADD DIALOG
  // ============================================================
  Future<void> _showAddProductDialog() async {
    final List<dynamic> categoryRows;
    try {
      categoryRows = await supabase
          .from('categories')
          .select('id, name')
          .order('name');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kategori gagal dimuat dari database: $error')),
      );
      return;
    }
    if (!mounted) return;

    final categoryOptions = categoryRows
        .map(
          (row) => {
            'id': row['id']?.toString() ?? '',
            'name': row['name']?.toString() ?? '',
          },
        )
        .where((category) => category['id']!.isNotEmpty)
        .toList();
    if (categoryOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada kategori. Jalankan migration kategori produk terlebih dahulu.',
          ),
        ),
      );
      return;
    }

    final nameC = TextEditingController();
    final brandC = TextEditingController();
    final priceC = TextEditingController();
    final origPriceC = TextEditingController();
    final stockC = TextEditingController(text: '10');
    final descC = TextEditingController();
    final productId = 'admin-${DateTime.now().microsecondsSinceEpoch}';
    String? imageUrl;
    String selectedCategory = categoryOptions.first['id']!;
    bool isFlashSale = false;
    bool isImageUploading = false;

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
                    items: categoryOptions
                        .map(
                          (category) => DropdownMenuItem(
                            value: category['id'],
                            child: Text(category['name']!),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null)
                        setDialogState(() => selectedCategory = val);
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
                  ProductImagePicker(
                    productId: productId,
                    onChanged: (url) => setDialogState(() => imageUrl = url),
                    onUploadingChanged: (uploading) =>
                        setDialogState(() => isImageUploading = uploading),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Langsung Masukkan Flash Sale'),
                    value: isFlashSale,
                    activeColor: AppColors.error,
                    onChanged: (val) => setDialogState(() => isFlashSale = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isFlashSale) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: origPriceC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga Asli Coret (Rp)',
                        hintText: 'Contoh: 18000000',
                        border: OutlineInputBorder(),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: isImageUploading
                  ? null
                  : () async {
                      final name = nameC.text.trim();
                      final brand = brandC.text.trim();
                      final price = _parseDouble(priceC.text.trim());
                      final stock = _parseInt(stockC.text.trim());

                      if (name.isEmpty || brand.isEmpty || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nama, Brand, dan Harga wajib diisi'),
                          ),
                        );
                        return;
                      }

                      double? origPrice;
                      if (isFlashSale) {
                        origPrice = _parseDouble(origPriceC.text.trim());
                        if (origPrice <= price) {
                          origPrice = price * 1.25;
                        }
                      }

                      final newProduct = ProductModel(
                        id: productId,
                        name: name,
                        description: descC.text.trim().isEmpty
                            ? name
                            : descC.text.trim(),
                        descriptionId: descC.text.trim().isEmpty
                            ? name
                            : descC.text.trim(),
                        price: price,
                        originalPrice: origPrice,
                        categoryId: selectedCategory,
                        brand: brand,
                        images: imageUrl == null ? [] : [imageUrl!],
                        specs: {},
                        rating: 0,
                        reviewCount: 0,
                        stock: stock,
                        isNew: true,
                        isOnSale: isFlashSale,
                      );

                      final nav = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      final productProvider = context.read<ProductProvider>();

                      try {
                        await productProvider.addProduct(newProduct);
                        if (ctx.mounted) nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Produk berhasil ditambahkan'),
                          ),
                        );
                        if (mounted) _loadData();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Gagal menambahkan produk: $e'),
                          ),
                        );
                      }
                    },
              child: Text(isImageUploading ? 'Mengunggah foto...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    final existingProduct = ProductModel.fromMap(product);
    String? imageUrl = existingProduct.images.isNotEmpty
        ? existingProduct.images.first
        : null;
    var imageWasChanged = false;
    final stockController = TextEditingController(
      text: (product['stock'] ?? 0).toString(),
    );
    final priceController = TextEditingController(
      text: (product['price'] ?? 0).toString(),
    );
    final nameController = TextEditingController(
      text: product['name']?.toString() ?? '',
    );
    final brandController = TextEditingController(
      text: product['brand']?.toString() ?? '',
    );
    final descController = TextEditingController(
      text: product['description']?.toString() ?? '',
    );
    var isImageUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Produk', style: AppTextStyles.titleMedium),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Produk',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: brandController,
                    decoration: const InputDecoration(
                      labelText: 'Brand',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga (Rp)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ProductImagePicker(
                    productId: existingProduct.id,
                    initialImageUrl: imageUrl,
                    onChanged: (url) {
                      imageUrl = url;
                      imageWasChanged = true;
                    },
                    onUploadingChanged: (uploading) =>
                        setDialogState(() => isImageUploading = uploading),
                  ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: isImageUploading
                  ? null
                  : () async {
                      final nav = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      final productProvider = context.read<ProductProvider>();

                      try {
                        final oldImageUrl = existingProduct.images.isNotEmpty
                            ? existingProduct.images.first
                            : null;
                        final editedProduct = existingProduct.copyWith(
                          name: nameController.text.trim(),
                          brand: brandController.text.trim(),
                          price: _parseDouble(priceController.text.trim()),
                          stock: _parseInt(stockController.text.trim()),
                          description: descController.text.trim(),
                          descriptionId: descController.text.trim(),
                          images: imageWasChanged
                              ? (imageUrl == null ? [] : [imageUrl!])
                              : existingProduct.images,
                        );
                        await productProvider.updateProduct(editedProduct);
                        if (imageWasChanged && oldImageUrl != imageUrl) {
                          try {
                            await ProductImageStorageService.deleteProductImage(
                              oldImageUrl,
                            );
                          } catch (e) {
                            debugPrint('Old product image cleanup failed: $e');
                          }
                        }

                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Produk berhasil diupdate'),
                          ),
                        );
                        if (mounted) _loadData();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Gagal: $e')),
                        );
                      }
                    },
              child: Text(isImageUploading ? 'Mengunggah foto...' : 'Simpan'),
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
        content: Text(
          'Apakah Anda yakin ingin menghapus "${product['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final productProvider = context.read<ProductProvider>();
                final deletedProduct = ProductModel.fromMap(product);
                await productProvider.deleteProduct(
                  product['id']?.toString() ?? '',
                );
                if (deletedProduct.images.isNotEmpty) {
                  try {
                    await ProductImageStorageService.deleteProductImage(
                      deletedProduct.images.first,
                    );
                  } catch (e) {
                    debugPrint('Product image cleanup failed: $e');
                  }
                }
              } catch (e) {
                debugPrint('Delete product error: $e');
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal menghapus produk: $e')),
                );
                return;
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
// FLASH SALE CONFIGURATION BOTTOM SHEET (ROBUST & RESPONSIVE)
// ============================================================
class _FlashSaleSheetWidget extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;
  final VoidCallback onSaved;

  const _FlashSaleSheetWidget({
    required this.initialProduct,
    required this.onSaved,
  });

  @override
  State<_FlashSaleSheetWidget> createState() => _FlashSaleSheetWidgetState();
}

class _FlashSaleSheetWidgetState extends State<_FlashSaleSheetWidget> {
  ProductModel? _selectedProduct;
  final TextEditingController _searchC = TextEditingController();
  final TextEditingController _salePriceC = TextEditingController();
  final TextEditingController _origPriceC = TextEditingController();
  int _discountPct = 20;
  bool _isInit = false;

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      final provider = context.read<ProductProvider>();

      if (widget.initialProduct != null) {
        final id = widget.initialProduct!['id']?.toString() ?? '';
        _selectedProduct = provider.getProductById(id);
      }

      _recalculatePrices();
    }
  }

  void _recalculatePrices() {
    if (_selectedProduct == null) return;
    final basePrice =
        _selectedProduct!.originalPrice ?? _selectedProduct!.price;
    final discounted = basePrice * (1 - _discountPct / 100);
    _origPriceC.text = basePrice.toStringAsFixed(0);
    _salePriceC.text = discounted.toStringAsFixed(0);
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final nonFlashProducts = provider.allProducts.where((p) {
      final matchesSearch =
          _searchC.text.isEmpty ||
          p.name.toLowerCase().contains(_searchC.text.toLowerCase()) ||
          p.brand.toLowerCase().contains(_searchC.text.toLowerCase());
      return matchesSearch;
    }).toList();

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
                    Icon(
                      Icons.local_fire_department,
                      color: AppColors.error,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedProduct != null
                            ? 'Atur Promo Flash Sale'
                            : 'Pilih Produk untuk Flash Sale',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),

                if (_selectedProduct == null) ...[
                  Text(
                    'Cari dan pilih produk dari katalog toko:',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchC,
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau brand produk...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: nonFlashProducts.isEmpty
                        ? const Center(
                            child: Text('Tidak ada produk yang cocok'),
                          )
                        : ListView.builder(
                            itemCount: nonFlashProducts.length,
                            itemBuilder: (ctx, i) {
                              final p = nonFlashProducts[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'Rp ${_formatNumber(p.price)} • Stok: ${p.stock}',
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedProduct = p;
                                      _recalculatePrices();
                                    });
                                  },
                                  child: const Text(
                                    'Pilih',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
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
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedProduct!.name,
                                style: AppTextStyles.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Brand: ${_selectedProduct!.brand} • Harga Normal: Rp ${_formatNumber(_selectedProduct!.originalPrice ?? _selectedProduct!.price)}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedProduct = null;
                            });
                          },
                          child: const Text('Ganti'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Persentase Diskon Promo (%)',
                    style: AppTextStyles.bodySmall,
                  ),
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
                          onChanged: (val) {
                            setState(() {
                              _discountPct = val.round();
                              _recalculatePrices();
                            });
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-$_discountPct%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _origPriceC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Asli Coret (Rp)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _salePriceC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Promo Flash Sale (Rp)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
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
                          onPressed: () async {
                            final salePrice = _parseDouble(
                              _salePriceC.text.trim(),
                            );
                            final originalPrice = _parseDouble(
                              _origPriceC.text.trim(),
                            );

                            if (salePrice <= 0 || salePrice >= originalPrice) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Harga promo harus lebih kecil dari harga asli',
                                  ),
                                ),
                              );
                              return;
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(context);

                            await provider.toggleFlashSale(
                              _selectedProduct!.id,
                              true,
                              salePrice: salePrice,
                              originalPrice: originalPrice,
                            );

                            try {
                              await Supabase.instance.client
                                  .from('products')
                                  .update({
                                    'is_on_sale': true,
                                    'price': salePrice,
                                    'original_price': originalPrice,
                                  })
                                  .eq('id', _selectedProduct!.id);
                            } catch (e) {
                              debugPrint('Supabase flash sale sync notice: $e');
                            }

                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Produk berhasil masuk ke Flash Sale',
                                ),
                              ),
                            );
                            widget.onSaved();
                          },
                          child: const Text('Aktifkan Flash Sale'),
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
