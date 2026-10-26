import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/data/models/review_model.dart';

/// Ulasan produk. Semua data berasal dari tabel `reviews` di Supabase
/// (tidak ada data contoh atau cache lokal).
class ReviewProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<ReviewModel> _reviews = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ReviewModel> get allReviews => _reviews;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ReviewProvider() {
    _loadReviews();
  }

  List<ReviewModel> getReviewsForProduct(String productId) {
    return _reviews.where((r) => r.productId == productId).toList();
  }

  /// Ulasan untuk satu item (produk) di dalam satu pesanan, jika sudah ada.
  ReviewModel? reviewForOrderItem(String orderId, String productId) {
    final currentUserId = supabase.auth.currentUser?.id;
    for (final r in _reviews) {
      if (r.orderId == orderId &&
          r.productId == productId &&
          (currentUserId == null || r.userId == currentUserId)) {
        return r;
      }
    }
    return null;
  }

  Future<void> _loadReviews() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List res = await supabase
          .from('reviews')
          .select()
          .order('date', ascending: false);
      _reviews = res
          .map((item) => ReviewModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading reviews from Supabase: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Mengirim atau mengubah ulasan satu item pesanan lewat RPC
  /// `submit_product_review` (server memeriksa pesanan, status, dan batas
  /// 7 hari). Rating produk dihitung ulang otomatis oleh trigger database.
  Future<bool> submitReview({
    required String orderId,
    required String productId,
    required double rating,
    required String comment,
    required List<String> mediaUrls,
  }) async {
    _errorMessage = null;
    try {
      await supabase.rpc(
        'submit_product_review',
        params: {
          'p_order_id': orderId,
          'p_product_id': productId,
          'p_rating': rating,
          'p_comment': comment,
          'p_media_urls': mediaUrls,
        },
      );
      await _loadReviews();
      return true;
    } on PostgrestException catch (e) {
      debugPrint('submitReview error: ${e.code} ${e.message}');
      if (e.message.contains('edit window')) {
        _errorMessage = 'Batas 7 hari untuk mengubah ulasan sudah lewat.';
      } else if (e.message.contains('cannot be reviewed')) {
        _errorMessage =
            'Ulasan hanya bisa dikirim untuk produk pada pesanan yang sudah selesai.';
      } else {
        _errorMessage = 'Ulasan gagal disimpan: ${e.message}';
      }
      return false;
    } catch (e) {
      debugPrint('submitReview error: $e');
      _errorMessage = 'Ulasan gagal disimpan. Periksa koneksi Anda.';
      return false;
    }
  }

  /// Admin / kasir membalas ulasan. Balasan disimpan di database.
  Future<bool> replyToReview({
    required String reviewId,
    required String replyText,
    required String replierRole,
  }) async {
    _errorMessage = null;
    final now = DateTime.now();
    try {
      final rows = await supabase
          .from('reviews')
          .update({
            'reply': replyText.trim(),
            'reply_role': replierRole,
            'reply_date': now.toUtc().toIso8601String(),
          })
          .eq('id', reviewId)
          .select('id');
      if (rows.isEmpty) {
        _errorMessage = 'Balasan tidak diizinkan atau ulasan tidak ditemukan.';
        return false;
      }

      final index = _reviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        _reviews[index] = _reviews[index].copyWith(
          reply: replyText.trim(),
          replyRole: replierRole,
          replyDate: now,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('replyToReview error: $e');
      _errorMessage = 'Balasan gagal disimpan.';
      return false;
    }
  }

  Future<void> refresh() async {
    await _loadReviews();
  }
}
