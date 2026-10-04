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
                        Text('Masuk untuk melanjutkan / Login to continue', style: AppTextStyles.titleMedium),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: GradientButton(
                            label: 'Masuk / Login',
                            onPressed: () => Navigator.pushNamed(context, AppRouter.login),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushNamed(context, AppRouter.register),
                            child: const Text('Daftar / Register'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final user = authProvider.currentUser!;
              final initials = user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?';

              return Column(
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: AppColors.surface,
                      child: Text(initials, style: AppTextStyles.heading2.copyWith(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(child: Text(user.fullName, style: AppTextStyles.heading3)),
                  Center(child: Text(user.email, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
                  const SizedBox(height: 8),
                  Center(
                    child: Chip(
                      label: Text(user.membershipTier.name.toUpperCase()),
                      side: BorderSide(color: _getTierColor(user.membershipTier)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: Text('${user.points} Points', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent))),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Progress Member', style: AppTextStyles.titleSmall),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: 0.6,
                            backgroundColor: AppColors.surface,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Current: ${user.membershipTier.name}'),
                              const Text('Next: Gold (400 pts)'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuItem(context, Icons.receipt_long, 'Pesanan Saya / My Orders', () => Navigator.pushNamed(context, AppRouter.orderHistory)),
                  Consumer<WishlistProvider>(
                    builder: (context, wishlist, child) => _buildMenuItem(
                      context, 
                      Icons.favorite, 
                      'Wishlist', 
                      () => Navigator.pushNamed(context, AppRouter.wishlist),
                      trailing: CircleAvatar(radius: 12, backgroundColor: AppColors.primary, child: Text('${wishlist.itemCount}', style: AppTextStyles.caption)),
                    ),
                  ),
                  _buildMenuItem(context, Icons.card_membership, 'Membership', () => Navigator.pushNamed(context, AppRouter.membership)),
                  _buildMenuItem(context, Icons.edit, 'Edit Profil / Edit Profile', () => Navigator.pushNamed(context, AppRouter.editProfile)),
                  _buildMenuItem(
                    context, 
                    Icons.dark_mode, 
                    'Tema / Theme', 
                    () { context.read<ThemeProvider>().toggleTheme(); }, 
                    trailing: Switch(
                      value: context.watch<ThemeProvider>().themeMode == ThemeMode.dark, 
                      onChanged: (v) { context.read<ThemeProvider>().toggleTheme(); },
                      activeColor: AppColors.primary,
                    ),
                  ),
                  _buildMenuItem(context, Icons.info_outline, 'Tentang / About', () {
                    showAboutDialog(context: context, applicationName: 'Doctor Computer', applicationVersion: '1.0.0');
                  }),
                  _buildMenuItem(context, Icons.logout, 'Keluar / Logout', () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Konfirmasi / Confirmation'),
                        content: const Text('Apakah Anda yakin ingin keluar? / Are you sure you want to logout?'),
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

  Color _getTierColor(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.bronze: return AppColors.bronze;
      case MembershipTier.silver: return AppColors.silver;
      case MembershipTier.gold: return AppColors.gold;
      case MembershipTier.platinum: return AppColors.platinum;
    }
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
