import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/data/models/review_model.dart';
import 'package:doctor_computer/data/mock/mock_pc_parts.dart';

class ReviewProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  static const String _prefReviewRepliesKey = 'admin_review_replies';
  static const String _prefCustomReviewsKey = 'custom_user_reviews';

  List<ReviewModel> _reviews = [];
  bool _isLoading = false;

  List<ReviewModel> get allReviews => _reviews;
  bool get isLoading => _isLoading;

  ReviewProvider() {
    _loadReviews();
  }

  List<ReviewModel> getReviewsForProduct(String productId) {
    return _reviews.where((r) => r.productId == productId).toList();
  }

  Future<void> _loadReviews() async {
    _isLoading = true;
    notifyListeners();

    // 1. Start with mock reviews
    final Map<String, ReviewModel> reviewMap = {};
    for (final r in mockReviews) {
      reviewMap[r.id] = r;
    }

    // 2. Load custom reviews from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final customJson = prefs.getString(_prefCustomReviewsKey);
      if (customJson != null && customJson.isNotEmpty) {
        final List list = jsonDecode(customJson);
        for (final item in list) {
          final review = ReviewModel.fromMap(item as Map<String, dynamic>);
          reviewMap[review.id] = review;
        }
      }
    } catch (e) {
      debugPrint('Error loading custom reviews from prefs: $e');
    }

    // 3. Load reviews from Supabase
    try {
      final List res = await supabase.from('reviews').select();
      for (final item in res) {
        final review = ReviewModel.fromMap(item as Map<String, dynamic>);
        reviewMap[review.id] = review;
      }
    } catch (e) {
      debugPrint('Error loading Supabase reviews: $e');
    }

    // 4. Merge cached admin/cashier replies from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final repliesJson = prefs.getString(_prefReviewRepliesKey);
      if (repliesJson != null && repliesJson.isNotEmpty) {
        final Map<String, dynamic> replies = jsonDecode(repliesJson);
        for (final entry in replies.entries) {
          final reviewId = entry.key;
          final replyData = entry.value as Map<String, dynamic>;
          if (reviewMap.containsKey(reviewId)) {
            final existing = reviewMap[reviewId]!;
            reviewMap[reviewId] = existing.copyWith(
              reply: replyData['reply']?.toString(),
              replyRole: replyData['reply_role']?.toString(),
              replyDate: replyData['reply_date'] != null
                  ? DateTime.tryParse(replyData['reply_date'].toString())
                  : null,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading review replies from prefs: $e');
    }

    _reviews = reviewMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> replyToReview({
    required String reviewId,
    required String replyText,
    required String replierRole,
  }) async {
    final now = DateTime.now();
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index == -1) return false;

    final updated = _reviews[index].copyWith(
      reply: replyText.trim(),
      replyRole: replierRole,
      replyDate: now,
    );
    _reviews[index] = updated;
    notifyListeners();

    // 1. Cache reply in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> replies = {};
      final existingJson = prefs.getString(_prefReviewRepliesKey);
      if (existingJson != null && existingJson.isNotEmpty) {
        replies = Map<String, dynamic>.from(jsonDecode(existingJson));
      }
      replies[reviewId] = {
        'reply': replyText.trim(),
        'reply_role': replierRole,
        'reply_date': now.toIso8601String(),
      };
      await prefs.setString(_prefReviewRepliesKey, jsonEncode(replies));
    } catch (e) {
      debugPrint('Error caching review reply: $e');
    }

    // 2. Attempt sync with Supabase reviews table
    try {
      await supabase.from('reviews').update({
        'reply': replyText.trim(),
        'reply_role': replierRole,
        'reply_date': now.toIso8601String(),
      }).eq('id', reviewId);
    } catch (e) {
      debugPrint('Supabase review reply update notice: $e');
    }

    return true;
  }

  Future<bool> addReview(ReviewModel review) async {
    _reviews.insert(0, review);
    notifyListeners();

    // Cache locally
    try {
      final prefs = await SharedPreferences.getInstance();
      final customJson = prefs.getString(_prefCustomReviewsKey);
      List<dynamic> list = [];
      if (customJson != null && customJson.isNotEmpty) {
        list = jsonDecode(customJson);
      }
      list.add(review.toMap());
      await prefs.setString(_prefCustomReviewsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving review locally: $e');
    }

    // Supabase insert
    try {
      await supabase.from('reviews').insert(review.toMap());
    } catch (e) {
      debugPrint('Error inserting review to Supabase: $e');
    }

    return true;
  }

  Future<void> refresh() async {
    await _loadReviews();
  }
}
