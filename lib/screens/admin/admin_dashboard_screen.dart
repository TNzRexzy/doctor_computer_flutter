import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/data/models/user_model.dart';
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
      length: isAdmin ? 4 : 2,
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
          tabs: [
            const Tab(icon: Icon(Icons.inventory), text: 'Produk'),
            const Tab(icon: Icon(Icons.receipt_long), text: 'Pesanan'),
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
                if (isAdmin) _buildUsersTab(),
                if (isAdmin) _buildStatsTab(),
              ],
            ),
    );
  }

  // ======================== PRODUCTS TAB ========================
  Widget _buildProductsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2),
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
                      Text(
                          'Harga: Rp ${_formatNumber(product['price'])}'),
                    ],
                  ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: AppColors.primary),
                onPressed: () => _showEditProductDialog(product),
              ),
            ),
          );
        },
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
                decoration: const InputDecoration(labelText: 'Nama Produk'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga (Rp)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stok'),
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
              try {
                await supabase.from('products').update({
                  'name': nameController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0,
                  'stock': int.tryParse(stockController.text) ?? 0,
                }).eq('id', product['id']);
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
                  decoration: const InputDecoration(labelText: 'Nama'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Points / EXP'),
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
                try {
                  await supabase.from('users').update({
                    'full_name': nameController.text.trim(),
                    'points': int.tryParse(pointsController.text) ?? 0,
                    'role': selectedRole,
                    'membership_tier': selectedTier,
                  }).eq('id', userData['id']);
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Pengguna berhasil diupdate')),
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
