/// Represents a product review.
class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String productId;
  final double rating;
  final String comment;
  final DateTime date;
  final String? reply;
  final String? replyRole;
  final DateTime? replyDate;
  final List<String> mediaUrls;

  const ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.productId,
    required this.rating,
    required this.comment,
    required this.date,
    this.reply,
    this.replyRole,
    this.replyDate,
    this.mediaUrls = const [],
  });

  ReviewModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? productId,
    double? rating,
    String? comment,
    DateTime? date,
    String? reply,
    String? replyRole,
    DateTime? replyDate,
    List<String>? mediaUrls,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      productId: productId ?? this.productId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      date: date ?? this.date,
      reply: reply ?? this.reply,
      replyRole: replyRole ?? this.replyRole,
      replyDate: replyDate ?? this.replyDate,
      mediaUrls: mediaUrls ?? this.mediaUrls,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'product_id': productId,
      'rating': rating,
      'comment': comment,
      'date': date.toIso8601String(),
      'reply': reply,
      'reply_role': replyRole,
      'reply_date': replyDate?.toIso8601String(),
      'media_urls': mediaUrls,
    };
  }

  /// Map matching exactly the Supabase reviews table schema
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'product_id': productId,
      'rating': rating,
      'comment': comment,
      'date': date.toIso8601String(),
      'reply': reply,
      'reply_role': replyRole,
      if (replyDate != null) 'reply_date': replyDate!.toIso8601String(),
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedMedia = [];
    if (map['media_urls'] is List) {
      parsedMedia = (map['media_urls'] as List).map((e) => e.toString()).toList();
    }
    return ReviewModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      userName: map['user_name']?.toString() ?? 'Pengguna',
      productId: map['product_id']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      comment: map['comment']?.toString() ?? '',
      date: map['date'] != null
          ? (DateTime.tryParse(map['date'].toString()) ?? DateTime.now())
          : (map['created_at'] != null
              ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
              : DateTime.now()),
      reply: map['reply']?.toString(),
      replyRole: map['reply_role']?.toString(),
      replyDate: map['reply_date'] != null
          ? DateTime.tryParse(map['reply_date'].toString())
          : null,
      mediaUrls: parsedMedia,
    );
  }
}
