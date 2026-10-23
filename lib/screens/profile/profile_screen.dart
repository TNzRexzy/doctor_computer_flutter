import 'package:doctor_computer/core/utils/image_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/providers/theme_provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/wishlist_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/screens/ai_chat/ai_customer_service_screen.dart';
import 'package:doctor_computer/screens/warranty/warranty_check_screen.dart';
import 'package:doctor_computer/screens/member/member_screen.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';
import 'package:doctor_computer/core/constants/app_constants.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (!authProvider.isLoggedIn) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline, size: 80, color: AppColors.textTertiary),
                        Text('Masuk untuk melanjutkan', style: AppTextStyles.titleMedium),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: GradientButton(
                            label: 'Masuk',
                            onPressed: () => Navigator.pushNamed(context, AppRouter.login),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushNamed(context, AppRouter.register),
                            child: const Text('Daftar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final user = authProvider.currentUser!;
              final initials = user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?';
              final blockchain = context.watch<BlockchainProvider>();
              final isAdmin = user.role == UserRole.admin;

              // Ensure blockchain wallet matches admin level
              if (isAdmin) {
                blockchain.syncWithUser(user.id, user.fullName, true);
              }

              final effectiveExp = isAdmin
                  ? 999999
                  : (blockchain.totalExp >= user.points ? blockchain.totalExp : user.points);
              final currentTier = isAdmin
                  ? MemberTier.platinum
                  : MemberTier.fromExp(effectiveExp);
              final totalExp = effectiveExp;
              final nextTier = isAdmin ? null : currentTier.getNextTier();

              final progress = isAdmin
                  ? 1.0
                  : (nextTier != null
                      ? ((totalExp - currentTier.value) / (nextTier.value - currentTier.value)).clamp(0.0, 1.0)
                      : 1.0);

              return Column(
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: AppColors.surface,
                      backgroundImage: AppImageHelper.getImageProvider(user.profileImageUrl),
                      child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
                          ? Text(initials, style: AppTextStyles.heading2.copyWith(color: AppColors.primary))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(child: Text(user.fullName, style: AppTextStyles.heading3)),
                  Center(child: Text(user.email, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
                  const SizedBox(height: 8),
                  Center(
                    child: Chip(
                      label: Text(
                        isAdmin ? 'PLATINUM (MAX)' : currentTier.name.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Color(currentTier.color).withValues(alpha: 0.15),
                      side: BorderSide(color: Color(currentTier.color)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      isAdmin ? '999,999 EXP (MAX) • Level Tertinggi' : '$totalExp EXP (Diskon ${currentTier.discountPercent}%)',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('Progress Member (Blockchain)', style: AppTextStyles.titleSmall),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isAdmin
                                    ? 'Maksimal (Platinum)'
                                    : (nextTier != null
                                        ? '${nextTier.value - totalExp} EXP lagi ke ${nextTier.name}'
                                        : 'Maksimal (${currentTier.name})'),
                                style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: AppColors.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(currentTier.color)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Current: ${isAdmin ? 'Platinum (MAX)' : currentTier.name}', style: AppTextStyles.caption),
                              Text(
                                isAdmin
                                    ? 'Level Tertinggi (Maksimal)'
                                    : (nextTier != null ? 'Next: ${nextTier.name}' : 'Level Tertinggi'),
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuItem(context, Icons.receipt_long, 'Pesanan Saya', () => Navigator.pushNamed(context, AppRouter.orderHistory)),
                  Consumer<WishlistProvider>(
                    builder: (context, wishlist, child) => _buildMenuItem(
                      context, 
                      Icons.favorite, 
                      'Wishlist', 
                      () => Navigator.pushNamed(context, AppRouter.wishlist),
                      trailing: CircleAvatar(radius: 12, backgroundColor: AppColors.primary, child: Text('${wishlist.itemCount}', style: AppTextStyles.caption)),
                    ),
                  ),
                  _buildMenuItem(context, Icons.smart_toy, 'Tanya Dokter AI (Customer Service)', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AiCustomerServiceScreen()));
                  }),
                  _buildMenuItem(context, Icons.verified_user, 'Cek Masa Garansi Aktif', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const WarrantyCheckScreen()));
                  }),
                  _buildMenuItem(context, Icons.sports_esports, 'Minigames & Blockchain Member', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MemberScreen()));
                  }),
                  _buildMenuItem(context, Icons.card_membership, 'Membership', () => Navigator.pushNamed(context, AppRouter.membership)),
                  if (user.role == UserRole.admin || user.role == UserRole.cashier)
                    _buildMenuItem(
                      context, 
                      Icons.admin_panel_settings, 
                      user.role == UserRole.admin ? 'Dashboard Admin' : 'Dashboard Kasir', 
                      () => Navigator.pushNamed(context, AppRouter.adminDashboard),
                      trailing: Chip(
                        label: Text(user.role.name.toUpperCase(), style: const TextStyle(fontSize: 10)),
                        backgroundColor: AppColors.warning,
                      ),
                    ),
                  _buildMenuItem(context, Icons.security, 'Keamanan & Privasi', () => Navigator.pushNamed(context, AppRouter.securitySettings)),
                  _buildMenuItem(context, Icons.edit, 'Edit Profil', () => Navigator.pushNamed(context, AppRouter.editProfile)),
                  _buildMenuItem(
                    context, 
                    Icons.dark_mode, 
                    'Tema', 
                    () { context.read<ThemeProvider>().toggleTheme(); }, 
                    trailing: Switch(
                      value: context.watch<ThemeProvider>().themeMode == ThemeMode.dark, 
                      onChanged: (v) { context.read<ThemeProvider>().toggleTheme(); },
                      activeColor: AppColors.primary,
                    ),
                  ),
                  _buildMenuItem(context, Icons.info_outline, 'Tentang', () {
                    showAboutDialog(
                      context: context, 
                      applicationName: 'Doctor Computer',
                      applicationVersion: 'Beta v${AppConstants.appVersion}',
                      applicationLegalese: '© 2026 Doctor Computer. All rights reserved.',
                      children: [
                        const SizedBox(height: 16),
                        Text('Aplikasi toko komputer dan perakitan PC terpercaya.', style: AppTextStyles.bodySmall),
                        const SizedBox(height: 8),
                        Text('Status: Beta', style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
                      ],
                    );
                  }),
                  _buildMenuItem(context, Icons.logout, 'Keluar', () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Konfirmasi'),
                        content: const Text('Apakah Anda yakin ingin keluar?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                          TextButton(
                            onPressed: () {
                              authProvider.logout();
                              Navigator.pop(ctx);
                              Navigator.pushReplacementNamed(context, AppRouter.login);
                            },
                            child: Text('Keluar', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                  }, color: AppColors.error),
                  const SizedBox(height: 100),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {Widget? trailing, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color ?? AppColors.primary),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: AppTextStyles.bodyMedium.copyWith(color: color))),
            if (trailing != null) trailing else Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
