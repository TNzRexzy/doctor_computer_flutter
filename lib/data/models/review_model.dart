/// Represents a product review.
class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String productId;
  final double rating;
  final String comment;
  final DateTime date;

  const ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.productId,
    required this.rating,
    required this.comment,
    required this.date,
  });
}
