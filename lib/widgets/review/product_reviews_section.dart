import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/review_model.dart';
import 'package:doctor_computer/providers/review_provider.dart';
import 'package:doctor_computer/services/review_media_service.dart';
import 'package:doctor_computer/widgets/common/app_image_view.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/review/review_media_viewer.dart';

/// Ulasan asli (dari database) untuk satu produk: ringkasan rating,
/// daftar ulasan lengkap dengan foto/video, dan balasan penjual.
class ProductReviewsSection extends StatefulWidget {
  final String productId;

  const ProductReviewsSection({super.key, required this.productId});

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  static const int _pageSize = 5;
  bool _onlyWithMedia = false;
  int _visible = _pageSize;

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReviewProvider>();
    final all = provider.getReviewsForProduct(widget.productId);
    final withMedia = all.where((r) => r.mediaUrls.isNotEmpty).toList();
    final shown = _onlyWithMedia ? withMedia : all;
    final visible = shown.take(_visible).toList();

    final average = all.isEmpty
        ? 0.0
        : all.fold<double>(0, (sum, r) => sum + r.rating) / all.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ulasan (${all.length})', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        if (provider.isLoading && all.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Belum ada ulasan untuk produk ini',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          )
        else ...[
          _buildSummary(all, average),
          const SizedBox(height: 12),
          Row(
            children: [
              ChoiceChip(
                label: Text('Semua (${all.length})'),
                selected: !_onlyWithMedia,
                onSelected: (_) => setState(() {
                  _onlyWithMedia = false;
                  _visible = _pageSize;
                }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Dengan Foto & Video (${withMedia.length})'),
                selected: _onlyWithMedia,
                onSelected: (_) => setState(() {
                  _onlyWithMedia = true;
                  _visible = _pageSize;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada ulasan dengan foto atau video.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ...visible.map(_buildReviewCard),
          if (shown.length > visible.length)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _visible += _pageSize),
                child: Text(
                  'Lihat ulasan lainnya (${shown.length - visible.length})',
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildSummary(List<ReviewModel> all, double average) {
    final counts = List<int>.filled(5, 0);
    for (final r in all) {
      final star = r.rating.round().clamp(1, 5);
      counts[star - 1]++;
    }
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                average.toStringAsFixed(1),
                style: AppTextStyles.heading2.copyWith(color: Colors.amber),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < average.round() ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text('${all.length} ulasan', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = counts[star - 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$star', style: AppTextStyles.caption),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 11, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: all.isEmpty ? 0 : count / all.length,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$count',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (r.userImageUrl != null && r.userImageUrl!.isNotEmpty) ...[
                  // Foto profil pembeli hanya tampil jika pembeli punya foto.
                  ClipOval(
                    child: Image.network(
                      r.userImageUrl!,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(width: 28, height: 28),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    r.userName,
                    style: AppTextStyles.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < r.rating.round() ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(r.date),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            if (r.comment.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                r.comment,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (r.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(r.mediaUrls.length, (i) {
                  final url = r.mediaUrls[i];
                  final isVideo = ReviewMediaService.isVideoUrl(url);
                  return GestureDetector(
                    onTap: () => showReviewMediaViewer(context, r.mediaUrls, i),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isVideo ? Colors.black : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isVideo
                            ? const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              )
                            : AppImageView(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                width: 72,
                                height: 72,
                              ),
                      ),
                    ),
                  );
                }),
              ),
            ],
            if (r.reply != null && r.reply!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Respon Penjual${r.replyRole != null ? ' - ${r.replyRole == 'admin' ? 'Admin' : 'Kasir'}' : ''}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r.reply!, style: AppTextStyles.bodySmall),
                    if (r.replyDate != null)
                      Text(
                        _formatDate(r.replyDate!),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
