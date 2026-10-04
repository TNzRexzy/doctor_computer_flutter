import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/providers/product_provider.dart';

/// Horizontal list of chips for sorting products.
class SortChips extends StatelessWidget {
  const SortChips({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final provider = context.watch<ProductProvider>();
    final currentSort = provider.sortBy;

    const sorts = {
      'popular': 'Populer',
      'price_low': 'Termurah',
      'price_high': 'Termahal',
      'newest': 'Terbaru',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: sorts.entries.map((entry) {
          final isSelected = entry.key == currentSort;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              onSelected: (selected) {
                if (selected) {
                  provider.setSortBy(entry.key);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}


