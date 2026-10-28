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
import 'package:doctor_computer/widgets/ai_chat/doctor_ai_floating.dart';
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
                        Icon(
                          Icons.person_outline,
                          size: 80,
                          color: AppColors.textTertiary,
                        ),
                        Text(
                          'Masuk untuk melanjutkan',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: GradientButton(
                            label: 'Masuk',
                            onPressed: () =>
                                Navigator.pushNamed(context, AppRouter.login),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRouter.register,
                            ),
                            child: const Text('Daftar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final user = authProvider.currentUser!;
              final initials = user.fullName.isNotEmpty
                  ? user.fullName[0].toUpperCase()
                  : '?';
              final blockchain = context.watch<BlockchainProvider>();
              final isAdmin = user.role == UserRole.admin;

              // Ensure blockchain wallet matches admin level
              if (isAdmin) {
                blockchain.syncWithUser(user.id, user.fullName, true);
              }

              final currentTier = isAdmin
                  ? MemberTier.platinum
                  : blockchain.currentTier;
              final totalExp = isAdmin ? 999999 : blockchain.totalExp;
              final nextTier = isAdmin ? null : currentTier.getNextTier();

              final progress = isAdmin
                  ? 1.0
                  : (nextTier != null
                        ? ((totalExp - currentTier.value) /
                                  (nextTier.value - currentTier.value))
                              .clamp(0.0, 1.0)
                        : 1.0);

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.buttonText.withValues(
                                  alpha: 0.4,
                                ),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 31,
                              backgroundColor: AppColors.surface,
                              backgroundImage:
                                  user.profileImageUrl != null &&
                                      user.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(user.profileImageUrl!)
                                  : null,
                              child:
                                  user.profileImageUrl == null ||
                                      user.profileImageUrl!.isEmpty
                                  ? Text(
                                      initials,
                                      style: AppTextStyles.heading2.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: AppColors.buttonText,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  user.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.buttonText.withValues(
                                      alpha: 0.78,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _buildProfileBadge(
                                      isAdmin
                                          ? 'PLATINUM • ADMIN'
                                          : currentTier.name.toUpperCase(),
                                      Icons.workspace_premium_outlined,
                                    ),
                                    _buildProfileBadge(
                                      isAdmin
                                          ? '999,999 EXP'
                                          : '$totalExp EXP • Diskon ${currentTier.discountPercent}%',
                                      Icons.bolt_rounded,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Edit profil',
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRouter.editProfile,
                            ),
                            icon: Icon(
                              Icons.edit_outlined,
                              color: AppColors.buttonText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GlassCard(
                      padding: const EdgeInsets.all(18),
                      borderRadius: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Progress Member (Blockchain)',
                                  style: AppTextStyles.titleSmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isAdmin
                                    ? 'Maksimal (Platinum)'
                                    : (nextTier != null
                                          ? '${nextTier.value - totalExp} EXP lagi ke ${nextTier.name}'
                                          : 'Maksimal (${currentTier.name})'),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 12,
                              backgroundColor: AppColors.textTertiary
                                  .withValues(alpha: 0.32),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Current: ${isAdmin ? 'Platinum (MAX)' : currentTier.name}',
                                style: AppTextStyles.caption,
                              ),
                              Text(
                                isAdmin
                                    ? 'Level Tertinggi (Maksimal)'
                                    : (nextTier != null
                                          ? 'Next: ${nextTier.name}'
                                          : 'Level Tertinggi'),
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildSectionLabel('Akun & aktivitas'),
                  _buildMenuItem(
                    context,
                    Icons.receipt_long,
                    'Pesanan Saya',
                    () => Navigator.pushNamed(context, AppRouter.orderHistory),
                  ),
                  Consumer<WishlistProvider>(
                    builder: (context, wishlist, child) => _buildMenuItem(
                      context,
                      Icons.favorite,
                      'Wishlist',
                      () => Navigator.pushNamed(context, AppRouter.wishlist),
                      trailing: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          '${wishlist.itemCount}',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    Icons.smart_toy,
                    'Tanya Dokter AI (Customer Service)',
                    () {
                      DoctorAiController.instance.open();
                    },
                  ),
                  _buildMenuItem(
                    context,
                    Icons.verified_user,
                    'Cek Masa Garansi Aktif',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WarrantyCheckScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    Icons.sports_esports,
                    'Minigames & Blockchain Member',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MemberScreen()),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    Icons.card_membership,
                    'Membership',
                    () => Navigator.pushNamed(context, AppRouter.membership),
                  ),
                  _buildSectionLabel('Pengaturan & akses'),
                  if (user.role == UserRole.admin)
                    _buildMenuItem(
                      context,
                      Icons.admin_panel_settings,
                      'Dashboard Admin',
                      () => Navigator.pushNamed(
                        context,
                        AppRouter.adminDashboard,
                      ),
                      trailing: Chip(
                        label: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    ),
                  if (user.role == UserRole.admin ||
                      user.role == UserRole.cashier)
                    _buildMenuItem(
                      context,
                      Icons.point_of_sale,
                      'Dashboard Kasir & POS',
                      () => Navigator.pushNamed(
                        context,
                        AppRouter.cashierDashboard,
                      ),
                      trailing: const Chip(
                        label: Text(
                          'KASIR',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Color(0xFF6D28D9),
                      ),
                    ),
                  _buildMenuItem(
                    context,
                    Icons.edit,
                    'Edit Profil',
                    () => Navigator.pushNamed(context, AppRouter.editProfile),
                  ),
                  _buildMenuItem(
                    context,
                    Icons.fingerprint,
                    'Keamanan',
                    () => Navigator.pushNamed(context, AppRouter.security),
                  ),
                  _buildMenuItem(
                    context,
                    Icons.dark_mode,
                    'Tema',
                    () {
                      context.read<ThemeProvider>().toggleTheme();
                    },
                    trailing: Switch(
                      value:
                          context.watch<ThemeProvider>().themeMode ==
                          ThemeMode.dark,
                      onChanged: (v) {
                        context.read<ThemeProvider>().toggleTheme();
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                  _buildMenuItem(context, Icons.info_outline, 'Tentang', () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Doctor Computer',
                      applicationVersion: 'v${AppConstants.appVersion}',
                      applicationLegalese:
                          '© 2026 Doctor Computer. All rights reserved.',
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Aplikasi toko komputer dan perakitan PC terpercaya.',
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Release version',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                          ),
                        ),
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
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () {
                              authProvider.logout();
                              Navigator.pop(ctx);
                              Navigator.pushReplacementNamed(
                                context,
                                AppRouter.login,
                              );
                            },
                            child: Text(
                              'Keluar',
                              style: TextStyle(color: AppColors.error),
                            ),
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

  Widget _buildProfileBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.buttonText.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.buttonText),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.buttonText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    Widget? trailing,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
        borderRadius: 18,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (color ?? AppColors.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color ?? AppColors.primary, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: color ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
