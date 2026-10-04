import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';

/// A custom AppBar with optional transparency and gradient overlay.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool showBack;
  final bool transparent;

  const CustomAppBar({
    super.key,
    this.title,
    this.actions,
    this.showBack = true,
    this.transparent = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: transparent ? Colors.transparent : AppColors.background,
      elevation: 0,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: title != null
          ? Text(
              title!,
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
            )
          : null,
      actions: actions,
      flexibleSpace: transparent
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background,
                    AppColors.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
