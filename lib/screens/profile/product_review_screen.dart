import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/models/review_model.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/product_provider.dart';
import 'package:doctor_computer/providers/review_provider.dart';
import 'package:doctor_computer/services/review_media_service.dart';
import 'package:doctor_computer/widgets/common/app_image_view.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';

/// Form ulasan untuk SATU produk di dalam satu pesanan yang sudah selesai
/// (bintang, teks, foto, video). Mengembalikan `true` jika berhasil disimpan.
class ProductReviewScreen extends StatefulWidget {
  final OrderModel order;
  final CartItemModel item;
  final ReviewModel? existing;

  const ProductReviewScreen({
    super.key,
    required this.order,
    required this.item,
    this.existing,
  });

  @override
  State<ProductReviewScreen> createState() => _ProductReviewScreenState();
}

class _PickedMedia {
  final XFile file;
  final bool isVideo;
  final Uint8List? previewBytes;

  const _PickedMedia(this.file, this.isVideo, this.previewBytes);
}

class _ProductReviewScreenState extends State<ProductReviewScreen> {
  static const List<String> _ratingLabels = [
    'Buruk',
    'Kurang',
    'Cukup',
    'Bagus',
    'Sangat Bagus',
  ];

  late double _rating;
  late final TextEditingController _commentController;
  late final List<String> _existingMedia;
  final List<_PickedMedia> _newMedia = [];
  final List<String> _removedMedia = [];
  bool _isBusy = false;
  String _busyLabel = '';

  bool get _isEditing => widget.existing != null;

  int get _imageCount =>
      _existingMedia.where((u) => !ReviewMediaService.isVideoUrl(u)).length +
      _newMedia.where((m) => !m.isVideo).length;

  int get _videoCount =>
      _existingMedia.where(ReviewMediaService.isVideoUrl).length +
      _newMedia.where((m) => m.isVideo).length;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating ?? 5;
    _commentController = TextEditingController(
      text: widget.existing?.comment ?? '',
    );
    _existingMedia = List<String>.from(widget.existing?.mediaUrls ?? const []);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.error : AppColors.success,
        content: Text(message),
      ),
    );
  }

  Future<void> _addPhotos() async {
    final remaining = ReviewMediaService.maxImages - _imageCount;
    if (remaining <= 0) {
      _toast('Maksimal ${ReviewMediaService.maxImages} foto.');
      return;
    }
    try {
      final files = await ReviewMediaService.pickImages(remaining);
      for (final file in files) {
        final bytes = await file.readAsBytes();
        _newMedia.add(_PickedMedia(file, false, bytes));
      }
      if (mounted) setState(() {});
    } catch (e) {
      _toast('Gagal memilih foto.');
    }
  }

  Future<void> _addVideo() async {
    if (_videoCount >= ReviewMediaService.maxVideos) {
      _toast('Maksimal ${ReviewMediaService.maxVideos} video.');
      return;
    }
    try {
      final file = await ReviewMediaService.pickVideo();
      if (file == null) return;
      final size = await file.length();
      if (size > ReviewMediaService.maxVideoBytes) {
        _toast(
          'Ukuran video maksimal ${ReviewMediaService.maxVideoBytes ~/ (1024 * 1024)} MB.',
        );
        return;
      }
      setState(() => _newMedia.add(_PickedMedia(file, true, null)));
    } catch (e) {
      _toast('Gagal memilih video.');
    }
  }

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || _isBusy) return;

    final reviewProvider = context.read<ReviewProvider>();
    final productProvider = context.read<ProductProvider>();

    setState(() {
      _isBusy = true;
      _busyLabel = 'Mengunggah media...';
    });

    final uploaded = <String>[];
    try {
      for (final media in _newMedia) {
        uploaded.add(await ReviewMediaService.upload(media.file, user.id));
      }
    } on FormatException catch (e) {
      await _cleanup(uploaded);
      _fail(e.message);
      return;
    } catch (e) {
      await _cleanup(uploaded);
      _fail('Gagal mengunggah foto/video. Periksa koneksi Anda.');
      return;
    }

    if (mounted) setState(() => _busyLabel = 'Menyimpan ulasan...');
    final success = await reviewProvider.submitReview(
      orderId: widget.order.id,
      productId: widget.item.product.id,
      rating: _rating,
      comment: _commentController.text.trim(),
      mediaUrls: [..._existingMedia, ...uploaded],
    );

    if (!success) {
      await _cleanup(uploaded);
      _fail(reviewProvider.errorMessage ?? 'Ulasan tidak dapat disimpan.');
      return;
    }

    // Media lama yang dihapus pengguna dibersihkan dari storage.
    for (final url in _removedMedia) {
      await ReviewMediaService.deleteByUrl(url);
    }
    // Rating produk dihitung ulang di database; muat ulang daftar produk.
    await productProvider.reloadData();

    if (!mounted) return;
    _toast(
      _isEditing ? 'Ulasan berhasil diperbarui!' : 'Terima kasih atas ulasan Anda!',
      error: false,
    );
    Navigator.pop(context, true);
  }

  Future<void> _cleanup(List<String> uploaded) async {
    for (final url in uploaded) {
      await ReviewMediaService.deleteByUrl(url);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _isBusy = false);
    _toast(message);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.item.product;
    final ratingIndex = _rating.round().clamp(1, 5) - 1;

    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(
            _isEditing ? 'Ubah Ulasan' : 'Beri Ulasan',
            style: AppTextStyles.titleMedium,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppImageView(
                      imageUrl: product.images.isNotEmpty
                          ? product.images.first
                          : null,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: AppTextStyles.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Pesanan #${widget.order.id}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ulasan bisa diubah ${widget.existing!.remainingEditDays} hari lagi '
                    '(maksimal 7 hari sejak pertama dikirim).',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final star = i + 1.0;
                    return IconButton(
                      icon: Icon(
                        star <= _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                      onPressed: _isBusy
                          ? null
                          : () => setState(() => _rating = star),
                    );
                  }),
                ),
              ),
              Center(
                child: Text(
                  _ratingLabels[ratingIndex],
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _commentController,
                enabled: !_isBusy,
                maxLines: 5,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText:
                      'Bagikan pengalaman Anda tentang kualitas dan performa produk ini...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Foto & Video',
                style: AppTextStyles.titleSmall,
              ),
              Text(
                'Maksimal ${ReviewMediaService.maxImages} foto dan '
                '${ReviewMediaService.maxVideos} video '
                '(maks. ${ReviewMediaService.maxVideoDuration.inSeconds} detik).',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._existingMedia.map(
                    (url) => _mediaTile(
                      isVideo: ReviewMediaService.isVideoUrl(url),
                      child: AppImageView(
                        imageUrl: url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                      onRemove: () => setState(() {
                        _existingMedia.remove(url);
                        _removedMedia.add(url);
                      }),
                    ),
                  ),
                  ..._newMedia.map(
                    (media) => _mediaTile(
                      isVideo: media.isVideo,
                      child: media.previewBytes != null
                          ? Image.memory(
                              media.previewBytes!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox.shrink(),
                      onRemove: () => setState(() => _newMedia.remove(media)),
                    ),
                  ),
                  if (_imageCount < ReviewMediaService.maxImages)
                    _addTile(Icons.add_photo_alternate, 'Foto', _addPhotos),
                  if (_videoCount < ReviewMediaService.maxVideos)
                    _addTile(Icons.videocam, 'Video', _addVideo),
                ],
              ),
              const SizedBox(height: 28),
              if (_isBusy)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(_busyLabel, style: AppTextStyles.caption),
                  ],
                )
              else
                GradientButton(
                  label: _isEditing ? 'Simpan Perubahan' : 'Kirim Ulasan',
                  icon: Icons.send,
                  onPressed: _submit,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaTile({
    required bool isVideo,
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 80,
          height: 80,
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
                : child,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: _isBusy ? null : onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isBusy ? null : onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
