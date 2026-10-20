import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/review_provider.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/data/models/product_model.dart';
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

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    final isAdmin = user?.role == UserRole.admin;
    _tabController = TabController(
      length: isAdmin ? 5 : 3,
      vsync: this,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().currentUser;
      final isAdmin = user?.role == UserRole.admin;

      // Products - both admin and cashier can see
      final productsRes = await supabase.from('products').select();
      _products = List<Map<String, dynamic>>.from(productsRes);

      // Orders - both can see
      final ordersRes = await supabase.from('orders').select().order('order_date', ascending: false);
      _orders = List<Map<String, dynamic>>.from(ordersRes);

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
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            const Tab(icon: Icon(Icons.inventory), text: 'Produk'),
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
                _buildOrdersTab(),
                _buildReviewsTab(),
                if (isAdmin) _buildUsersTab(),
                if (isAdmin) _buildStatsTab(),
              ],
            ),
    );
  }

  // ======================== PRODUCTS TAB ========================
  Widget _buildProductsTab() {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _products.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    Text('Belum ada produk', style: AppTextStyles.bodyMedium),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  final isOnSale = product['is_on_sale'] == true;
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isOnSale
                              ? AppColors.error.withValues(alpha: 0.1)
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Brand: ${product['brand'] ?? '-'}'),
                          Row(
                            children: [
                              Text('Stok: ${product['stock'] ?? 0}',
                                  style: TextStyle(
                                      color: (product['stock'] ?? 0) < 5
                                          ? AppColors.error
                                          : AppColors.success,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                    'Harga: Rp ${_formatNumber(product['price'])}',
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          if (isOnSale)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'FLASH SALE',
                                    style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (product['original_price'] != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'Rp ${_formatNumber(product['original_price'])}',
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
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: AppColors.primary),
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _showEditProductDialog(product);
                              break;
                            case 'flash_sale':
                              _showFlashSaleDialog(product);
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
                            child: Text(isOnSale ? 'Hapus Flash Sale' : 'Atur Flash Sale'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Produk'),
      ),
    );
  }

  void _showAddProductDialog() {
    final nameC = TextEditingController();
    final brandC = TextEditingController();
    final priceC = TextEditingController();
    final origPriceC = TextEditingController();
    final stockC = TextEditingController(text: '10');
    final descC = TextEditingController();
    final imageUrlC = TextEditingController();
    String selectedCategory = 'laptop';
    bool isFlashSale = false;

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
          content: SingleChildScrollView(
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
                    hintText: 'Deskripsi produk...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageUrlC,
                  decoration: const InputDecoration(
                    labelText: 'URL Gambar (opsional)',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Flash Sale'),
                  subtitle: const Text('Aktifkan diskon promo'),
                  value: isFlashSale,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setDialogState(() => isFlashSale = val),
                  contentPadding: EdgeInsets.zero,
                ),
                if (isFlashSale) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: origPriceC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Asli (Rp) - sebelum diskon',
                      hintText: 'Contoh: 20000000',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
                final name = nameC.text.trim();
                final brand = brandC.text.trim();
                final price = double.tryParse(priceC.text.trim()) ?? 0;
                final stock = int.tryParse(stockC.text.trim()) ?? 10;

                if (name.isEmpty || brand.isEmpty || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama, Brand, dan Harga wajib diisi')),
                  );
                  return;
                }

                double? origPrice;
                if (isFlashSale) {
                  origPrice = double.tryParse(origPriceC.text.trim());
                  if (origPrice == null || origPrice <= price) {
                    origPrice = price * 1.25;
                  }
                }

                final productId = 'admin-${DateTime.now().millisecondsSinceEpoch}';
                final newProduct = ProductModel(
                  id: productId,
                  name: name,
                  description: descC.text.trim().isEmpty ? name : descC.text.trim(),
                  descriptionId: descC.text.trim().isEmpty ? name : descC.text.trim(),
                  price: price,
                  originalPrice: origPrice,
                  categoryId: selectedCategory,
                  brand: brand,
                  images: imageUrlC.text.trim().isNotEmpty ? [imageUrlC.text.trim()] : [],
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Produk', style: AppTextStyles.titleMedium),
        content: SingleChildScrollView(
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
              final productProvider = context.read<ProductProvider>();
              try {
                final updateData = {
                  'name': nameController.text.trim(),
                  'brand': brandController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0,
                  'stock': int.tryParse(stockController.text) ?? 0,
                  'description': descController.text.trim(),
                };

                await supabase.from('products').update(updateData).eq('id', product['id']);

                // Also update via ProductProvider for local sync
                try {
                  final existing = productProvider.getProductById(product['id']?.toString() ?? '');
                  if (existing != null) {
                    await productProvider.updateProduct(existing.copyWith(
                      name: updateData['name']?.toString(),
                      brand: updateData['brand']?.toString(),
                      price: (updateData['price'] as num?)?.toDouble(),
                      stock: (updateData['stock'] as num?)?.toInt(),
                      description: updateData['description']?.toString(),
                      descriptionId: updateData['description']?.toString(),
                    ));
                  }
                } catch (_) {}

                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Produk berhasil diupdate')),
                );
                if (mounted) _loadData();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal: $e')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showFlashSaleDialog(Map<String, dynamic> product) {
    final isCurrentlyOnSale = product['is_on_sale'] == true;
    final salePriceC = TextEditingController(
      text: isCurrentlyOnSale ? '' : (product['price'] ?? 0).toString(),
    );
    final origPriceC = TextEditingController(
      text: (product['original_price'] ?? product['price'] ?? 0).toString(),
    );
    int discountPct = 20;

    if (isCurrentlyOnSale) {
      // Turning off flash sale
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Nonaktifkan Flash Sale', style: AppTextStyles.titleMedium),
          content: Text(
            'Hapus status Flash Sale untuk "${product['name']}"?\n'
            'Harga akan dikembalikan ke harga asli.',
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
                  await productProvider.toggleFlashSale(product['id']?.toString() ?? '', false);

                  await supabase.from('products').update({
                    'is_on_sale': false,
                    'price': product['original_price'] ?? product['price'],
                    'original_price': null,
                  }).eq('id', product['id']);
                } catch (e) {
                  debugPrint('Flash sale toggle error: $e');
                }

                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Flash Sale dinonaktifkan')),
                );
                if (mounted) _loadData();
              },
              child: const Text('Nonaktifkan'),
            ),
          ],
        ),
      );
      return;
    }

    // Turning on flash sale
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentPrice = (product['price'] as num?)?.toDouble() ?? 0;

          void recalcSalePrice() {
            final salePrice = currentPrice * (1 - discountPct / 100);
            salePriceC.text = salePrice.toStringAsFixed(0);
            origPriceC.text = currentPrice.toStringAsFixed(0);
          }

          return AlertDialog(
            title: Text('Atur Flash Sale', style: AppTextStyles.titleMedium),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name']?.toString() ?? '-',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text('Harga saat ini: Rp ${_formatNumber(currentPrice)}',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 16),
                  Text('Diskon (%)', style: AppTextStyles.bodySmall),
                  Slider(
                    value: discountPct.toDouble(),
                    min: 5,
                    max: 80,
                    divisions: 15,
                    label: '$discountPct%',
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setDialogState(() {
                        discountPct = val.round();
                        recalcSalePrice();
                      });
                    },
                  ),
                  Text('Diskon: $discountPct%',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: origPriceC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Asli (Rp)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: salePriceC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Sale (Rp)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => setDialogState(() => recalcSalePrice()),
                    icon: const Icon(Icons.calculate, size: 16),
                    label: const Text('Hitung Otomatis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
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
                  final salePrice = double.tryParse(salePriceC.text.trim()) ?? 0;
                  final originalPrice = double.tryParse(origPriceC.text.trim()) ?? currentPrice;

                  if (salePrice <= 0 || salePrice >= originalPrice) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Harga sale harus lebih kecil dari harga asli')),
                    );
                    return;
                  }

                  try {
                    final productProvider = context.read<ProductProvider>();
                    await productProvider.toggleFlashSale(
                      product['id']?.toString() ?? '',
                      true,
                      salePrice: salePrice,
                      originalPrice: originalPrice,
                    );

                    await supabase.from('products').update({
                      'is_on_sale': true,
                      'price': salePrice,
                      'original_price': originalPrice,
                    }).eq('id', product['id']);
                  } catch (e) {
                    debugPrint('Flash sale set error: $e');
                  }

                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Flash Sale berhasil diaktifkan')),
                  );
                  if (mounted) _loadData();
                },
                child: const Text('Aktifkan Flash Sale'),
              ),
            ],
          );
        },
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
                await productProvider.deleteProduct(product['id']?.toString() ?? '');

                try {
                  await supabase.from('products').delete().eq('id', product['id']);
                } catch (e) {
                  debugPrint('Supabase delete notice: $e');
                }
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

  // ======================== ORDERS TAB ========================
  Widget _buildOrdersTab() {
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('Belum ada pesanan', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
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
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Total: Rp ${_formatNumber(order['total_price'])}'),
                  Row(
                    children: [
                      Chip(
                        label: Text(status.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white)),
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
    );
  }

  void _showEditOrderStatusDialog(Map<String, dynamic> order) {
    String selectedStatus = order['status']?.toString() ?? 'processing';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update Status Pesanan',
              style: AppTextStyles.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Order ID: ${order['id']}', style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
              ...['processing', 'shipped', 'delivered', 'cancelled']
                  .map((status) => RadioListTile<String>(
                        value: status,
                        groupValue: selectedStatus,
                        title: Text(status.toUpperCase()),
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedStatus = val);
                          }
                        },
                      )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await supabase.from('orders').update({
                    'status': selectedStatus,
                  }).eq('id', order['id']);
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Status pesanan diperbarui')),
                  );
                  if (mounted) _loadData();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Gagal: $e')),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  // ======================== REVIEWS TAB ========================
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
        padding: const EdgeInsets.all(16),
        itemCount: reviews.length,
        itemBuilder: (context, index) {
          final review = reviews[index];
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Review header
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
                            'Produk: ${review.productId}',
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

                // Existing reply
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

                // Reply button
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
              // Show original review
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

  // ======================== USERS TAB (ADMIN ONLY) ========================
  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final u = _users[index];
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
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u['email']?.toString() ?? '-',
                      style: AppTextStyles.caption),
                  Row(
                    children: [
                      Chip(
                        label: Text(tier.toUpperCase(),
                            style: const TextStyle(fontSize: 9)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      Chip(
                        label: Text(role.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 9, color: Colors.white)),
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
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.accent)),
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
          title: Text('Edit Pengguna', style: AppTextStyles.titleMedium),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${userData['email']}',
                    style: AppTextStyles.caption),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Poin',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Role:', style: AppTextStyles.bodySmall),
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
                ...['bronze', 'silver', 'gold', 'platinum']
                    .map((t) => RadioListTile<String>(
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
                        )),
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
                  backgroundColor: AppColors.primary),
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

                // 3. Attempt Supabase update
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
                        : 'Perubahan disimpan secara lokal'),
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

  // ======================== STATS TAB (ADMIN ONLY) ========================
  Widget _buildStatsTab() {
    final totalProducts = _products.length;
    final totalOrders = _orders.length;
    final totalUsers = _users.length;
    final lowStockProducts =
        _products.where((p) => (p['stock'] as num? ?? 0) < 5).length;
    final flashSaleCount =
        _products.where((p) => p['is_on_sale'] == true).length;
    final totalRevenue = _orders.fold<double>(
        0, (sum, o) => sum + ((o['total_price'] as num?)?.toDouble() ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Pendapatan', style: AppTextStyles.titleSmall),
                const SizedBox(height: 8),
                Text(
                  'Rp ${_formatNumber(totalRevenue)}',
                  style: AppTextStyles.heading2
                      .copyWith(color: AppColors.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Produk Stok Rendah', style: AppTextStyles.titleSmall),
                const SizedBox(height: 8),
                ..._products
                    .where((p) => (p['stock'] as num? ?? 0) < 5)
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.warning,
                                  size: 16, color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(p['name']?.toString() ?? '-')),
                              Text('Stok: ${p['stock'] ?? 0}',
                                  style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.heading3.copyWith(color: color)),
          Text(title, style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    final n = number is num ? number : num.tryParse(number.toString()) ?? 0;
    return n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );
  }
}
