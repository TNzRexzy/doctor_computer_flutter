import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/review_model.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/review_provider.dart';
import 'package:doctor_computer/services/review_media_service.dart';
import 'package:doctor_computer/widgets/common/app_image_view.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/review/review_media_viewer.dart';

/// Tab "Ulasan" untuk admin dan kasir: melihat ulasan pembeli (termasuk
/// foto/video) dan membalasnya, dengan template balasan cepat.
class ReviewManagementTab extends StatefulWidget {
  const ReviewManagementTab({super.key});

  @override
  State<ReviewManagementTab> createState() => _ReviewManagementTabState();
}

class _ReplyTemplate {
  final String label;
  final String text;
  const _ReplyTemplate(this.label, this.text);
}

class _ReviewManagementTabState extends State<ReviewManagementTab> {
  bool _onlyUnreplied = false;

  /// `{nama}` diganti dengan nama depan pembeli.
  static const List<_ReplyTemplate> _positiveTemplates = [
    _ReplyTemplate(
      'Terima kasih',
      'Terima kasih {nama} atas ulasan dan kepercayaannya kepada Doctor '
          'Computer. Kami senang produknya sesuai harapan Anda. Ditunggu '
          'pesanan berikutnya!',
    ),
    _ReplyTemplate(
      'Terima kasih foto/video',
      'Terima kasih {nama} sudah membagikan foto dan video produknya! '
          'Ulasan Anda sangat membantu pembeli lain.',
    ),
  ];

  static const List<_ReplyTemplate> _negativeTemplates = [
    _ReplyTemplate(
      'Mohon maaf',
      'Mohon maaf {nama} atas ketidaknyamanan yang Anda alami. Silakan '
          'hubungi kami lewat menu Bantuan di aplikasi agar kendalanya bisa '
          'segera kami tindak lanjuti.',
    ),
    _ReplyTemplate(
      'Klaim garansi',
      'Mohon maaf {nama}. Produk ini bergaransi resmi. Untuk klaim, buka '
          'menu Cek Garansi di aplikasi dan siapkan nomor seri pesanan Anda, '
          'tim kami akan membantu prosesnya.',
    ),
  ];

  static const List<_ReplyTemplate> _generalTemplates = [
    _ReplyTemplate(
      'Soal pengiriman',
      'Terima kasih {nama} atas masukannya mengenai pengiriman. Kami akan '
          'meneruskannya ke tim logistik agar layanan semakin baik.',
    ),
    _ReplyTemplate(
      'Terima kasih masukan',
      'Terima kasih {nama} atas masukannya. Ulasan Anda kami catat untuk '
          'peningkatan produk dan layanan Doctor Computer.',
    ),
  ];

  List<_ReplyTemplate> _templatesFor(ReviewModel review) {
    final primary = review.rating >= 4 ? _positiveTemplates : _negativeTemplates;
    final secondary = review.rating >= 4 ? _negativeTemplates : _positiveTemplates;
    return [...primary, ..._generalTemplates, ...secondary];
  }

  String _firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Kak';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String _productName(String productId) {
    final product = context.read<ProductProvider>().getProductById(productId);
    return product?.name ?? 'Produk $productId';
  }

  @override
  Widget build(BuildContext context) {
    final reviewProvider = context.watch<ReviewProvider>();
    final all = reviewProvider.allReviews;
    final unreplied = all
        .where((r) => r.reply == null || r.reply!.trim().isEmpty)
        .toList();
    final shown = _onlyUnreplied ? unreplied : all;

    if (reviewProvider.isLoading && all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              ChoiceChip(
                label: Text('Semua (${all.length})'),
                selected: !_onlyUnreplied,
                onSelected: (_) => setState(() => _onlyUnreplied = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Belum dibalas (${unreplied.length})'),
                selected: _onlyUnreplied,
                onSelected: (_) => setState(() => _onlyUnreplied = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: reviewProvider.refresh,
            child: shown.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        Icons.rate_review_outlined,
                        size: 64,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _onlyUnreplied
                              ? 'Semua ulasan sudah dibalas'
                              : 'Belum ada ulasan',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: shown.length,
                    itemBuilder: (context, index) => _buildCard(shown[index]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(ReviewModel review) {
    final hasReply = review.reply != null && review.reply!.isNotEmpty;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  review.userName.isNotEmpty
                      ? review.userName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName, style: AppTextStyles.titleSmall),
                    Text(
                      _productName(review.productId),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating.round() ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment, style: AppTextStyles.bodyMedium),
          ],
          if (review.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(review.mediaUrls.length, (i) {
                final url = review.mediaUrls[i];
                final isVideo = ReviewMediaService.isVideoUrl(url);
                return GestureDetector(
                  onTap: () => showReviewMediaViewer(context, review.mediaUrls, i),
                  child: Container(
                    width: 64,
                    height: 64,
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
                                size: 30,
                              ),
                            )
                          : AppImageView(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              width: 64,
                              height: 64,
                            ),
                    ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _formatDate(review.date),
            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          ),
          if (hasReply) ...[
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
                        'Respon Penjual${review.replyRole != null ? ' - ${review.replyRole == 'admin' ? 'Admin' : 'Kasir'}' : ''}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(review.reply!, style: AppTextStyles.bodySmall),
                  if (review.replyDate != null)
                    Text(
                      _formatDate(review.replyDate!),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showReplyDialog(review),
              icon: Icon(hasReply ? Icons.edit : Icons.reply, size: 16),
              label: Text(hasReply ? 'Edit Balasan' : 'Balas Ulasan'),
            ),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(ReviewModel review) {
    final replyController = TextEditingController(text: review.reply ?? '');
    final user = context.read<AuthProvider>().currentUser;
    final replierRole = user?.role == UserRole.admin ? 'admin' : 'cashier';
    final templates = _templatesFor(review);
    final firstName = _firstName(review.userName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Balas Ulasan', style: AppTextStyles.titleMedium),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName, style: AppTextStyles.titleSmall),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.comment.isEmpty ? '(tanpa teks)' : review.comment,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Template balasan:', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: templates.map((t) {
                  return ActionChip(
                    label: Text(t.label, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      replyController.text = t.text.replaceAll('{nama}', firstName);
                      replyController.selection = TextSelection.collapsed(
                        offset: replyController.text.length,
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                'Balasan Anda (${replierRole == 'admin' ? 'Admin' : 'Kasir'}):',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: replyController,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Tulis balasan atau pilih template di atas...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final replyText = replyController.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              if (replyText.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Balasan tidak boleh kosong')),
                );
                return;
              }

              final nav = Navigator.of(ctx);
              final reviewProvider = context.read<ReviewProvider>();
              final success = await reviewProvider.replyToReview(
                reviewId: review.id,
                replyText: replyText,
                replierRole: replierRole,
              );

              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Balasan berhasil disimpan'
                        : (reviewProvider.errorMessage ??
                              'Gagal menyimpan balasan'),
                  ),
                ),
              );
            },
            child: const Text('Kirim Balasan'),
          ),
        ],
      ),
    );
  }
}
