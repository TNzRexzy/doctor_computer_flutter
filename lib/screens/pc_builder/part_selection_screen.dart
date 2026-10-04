import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/currency_formatter.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/providers/pc_builder_provider.dart';
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
                Text('Pilih ${widget.category.displayNameId} / Select ${widget.category.displayName}', style: AppTextStyles.titleMedium),
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
                  hintText: 'Cari komponen / Search parts...',
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
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Icon(widget.category.icon, color: AppColors.primary),
                                    ),
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
                                                label: Text('${e.value}', style: AppTextStyles.caption),
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
                                      if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
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
