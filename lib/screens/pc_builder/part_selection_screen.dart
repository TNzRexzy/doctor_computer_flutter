import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/providers/pc_builder_provider.dart';
import 'package:doctor_computer/widgets/common/app_image_view.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';

class PartSelectionScreen extends StatefulWidget {
  final PcPartCategory category;

  const PartSelectionScreen({super.key, required this.category});

  @override
  State<PartSelectionScreen> createState() => _PartSelectionScreenState();
}

class _PartSelectionScreenState extends State<PartSelectionScreen> {
  String _searchQuery = '';
  String _sortBy = 'Semua';

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                Text('Pilih ${widget.category.displayNameId}', style: AppTextStyles.titleMedium),
                const Spacer(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Cari komponen...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildChoiceChip('Semua'),
                  const SizedBox(width: 8),
                  _buildChoiceChip('Price Low'),
                  const SizedBox(width: 8),
                  _buildChoiceChip('Price High'),
                ],
              ),
            ),
            Expanded(
              child: Consumer<PcBuilderProvider>(
                builder: (context, provider, child) {
                  var parts = provider.getPartsForCategory(widget.category);
                  if (_searchQuery.isNotEmpty) {
                    parts = parts.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
                  }
                  if (_sortBy == 'Price Low') {
                    parts.sort((a, b) => a.price.compareTo(b.price));
                  } else if (_sortBy == 'Price High') {
                    parts.sort((a, b) => b.price.compareTo(a.price));
                  }
                  
                  final selectedPart = provider.selectedParts[widget.category];

                  if (provider.isLoading && parts.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (parts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.category.icon, size: 40, color: AppColors.textTertiary),
                            const SizedBox(height: 12),
                            Text(
                              provider.errorMessage ??
                                  (_searchQuery.isNotEmpty
                                      ? 'Komponen tidak ditemukan'
                                      : 'Belum ada ${widget.category.displayNameId} di database'),
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            if (provider.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: provider.reloadParts,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Coba lagi'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: parts.length,
                    itemBuilder: (context, index) {
                      final part = parts[index];
                      final isSelected = selectedPart?.id == part.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: GlassCard(
                          padding: EdgeInsets.zero,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, part),
                            child: Container(
                              decoration: isSelected
                                  ? BoxDecoration(
                                      border: Border.all(color: AppColors.primary, width: 2),
                                      borderRadius: BorderRadius.circular(16),
                                    )
                                  : null,
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  AppImageView(
                                    imageUrl: part.imageUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.contain,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(part.name, style: AppTextStyles.titleSmall),
                                        Text(part.brand, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: part.specs.entries.take(2).map((e) {
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 4.0),
                                              child: Chip(
                                                label: Text(e.value, style: AppTextStyles.caption),
                                                padding: EdgeInsets.zero,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(formatRupiah(part.price), style: AppTextStyles.priceSmall),
                                      if (isSelected) Icon(Icons.check_circle, color: AppColors.primary),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _sortBy == label,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _sortBy = label;
          });
        }
      },
    );
  }
}
