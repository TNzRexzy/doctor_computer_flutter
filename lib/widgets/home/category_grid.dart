import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/category_model.dart';

class CategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;
  final Function(String categoryId) onCategoryTap;

  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => onCategoryTap(category.id),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category.icon,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.nameId,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

