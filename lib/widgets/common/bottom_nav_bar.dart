import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/cart_provider.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/widgets/common/badge_icon.dart';
import 'package:doctor_computer/widgets/common/app_image_view.dart';

/// A custom bottom navigation bar widget.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomInset > 0 ? bottomInset + 6 : 16,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      // Transparan penuh: tanpa kotak, border, atau bayangan di belakang menu.
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.category_rounded,
            label: 'Kategori',
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: Icons.build_rounded,
            label: 'Rakit PC',
            isActive: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          Consumer<CartProvider>(
            builder: (context, cart, child) {
              return _NavItem(
                icon: Icons.shopping_cart_rounded,
                label: 'Keranjang',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
                badgeCount: cart.itemCount,
              );
            },
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.currentUser;
              Widget? customAvatar;
              if (user != null) {
                final hasImage = user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty;
                customAvatar = Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: currentIndex == 4 ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: hasImage
                        ? AppImageView(
                            imageUrl: user.profileImageUrl!,
                            fit: BoxFit.cover,
                            width: 24,
                            height: 24,
                          )
                        : Container(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            alignment: Alignment.center,
                            child: Text(
                              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: currentIndex == 4 ? AppColors.primary : AppColors.textTertiary,
                              ),
                            ),
                          ),
                  ),
                );
              }
              return _NavItem(
                icon: Icons.person_rounded,
                customIcon: customAvatar,
                label: 'Profil',
                isActive: currentIndex == 4,
                onTap: () => onTap(4),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final Widget? customIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    this.customIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final color = isActive ? AppColors.primary : AppColors.textTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customIcon != null)
            customIcon!
          else if (badgeCount > 0)
            BadgeIcon(icon: icon, count: badgeCount, color: color)
          else
            Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.primary : Colors.transparent,
            ),
          )
        ],
      ),
    );
  }
}

