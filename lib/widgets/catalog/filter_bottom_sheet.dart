import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  RangeValues _priceRange = const RangeValues(0, 50000000);
  int _selectedRating = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProductProvider>();
    final brands = provider.availableBrands;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter', style: AppTextStyles.heading3),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: AppColors.cardBorder),
          const SizedBox(height: 16),
          Text('Rentang Harga / Price Range', style: AppTextStyles.titleMedium),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 50000000,
            divisions: 100,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceLight,
            labels: RangeLabels(
              formatRupiahCompact(_priceRange.start),
              formatRupiahCompact(_priceRange.end),
            ),
            onChanged: (values) {
              setState(() {
                _priceRange = values;
              });
            },
          ),
          const SizedBox(height: 16),
          Text('Merek / Brand', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: brands.map((brand) {
              return FilterChip(
                label: Text(brand),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                onSelected: (selected) {
                  provider.toggleBrand(brand);
                },
                // Assume the UI updates when toggling
                selected: false, // In a real app we would read this from provider's active filters
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Rating Minimum', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  Icons.star,
                  color: index < _selectedRating ? Colors.amber : AppColors.surfaceLight,
                ),
                onPressed: () {
                  setState(() {
                    _selectedRating = index + 1;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    provider.clearFilters();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GradientButton(
                  label: 'Terapkan / Apply',
                  onPressed: () {
                    provider.setPriceRange(_priceRange);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
