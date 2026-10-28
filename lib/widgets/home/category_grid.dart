import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/category_model.dart';

class CategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;
  final ValueChanged<String?> onCategoryTap;
  final String? selectedCategoryId;
  final bool showAllOption;

  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onCategoryTap,
    this.selectedCategoryId,
    this.showAllOption = false,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children:
            categories.map((category) {
              final isSelected = selectedCategoryId == category.id;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => onCategoryTap(category.id),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.cardBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          category.icon,
                          color: isSelected ? Colors.white : AppColors.primary,
                          size: isSelected ? 30 : 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: AppTextStyles.caption.copyWith(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        child: Text(
                          category.nameId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList()..insertAll(0, [
              if (showAllOption)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => onCategoryTap(null),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: selectedCategoryId == null
                                ? AppColors.primary
                                : AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedCategoryId == null
                                  ? AppColors.accent
                                  : AppColors.cardBorder,
                              width: selectedCategoryId == null ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            color: selectedCategoryId == null
                                ? Colors.white
                                : AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: AppTextStyles.caption.copyWith(
                            color: selectedCategoryId == null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: selectedCategoryId == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          child: const Text('Semua'),
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
      ),
    );
  }
}
