/// Status of a flash sale relative to the current time.
enum FlashSaleStatus { running, scheduled, ended, soldOut, inactive }

/// A flash sale row from the `flash_sales` table.
///
/// The normal price always stays in `products.price`. The flash price lives
/// only here, so ending a flash sale never needs to "restore" a price.
class FlashSaleModel {
  final String id;
  final String productId;
  final double originalPrice;
  final double flashPrice;
  final int flashStock;
  final int soldCount;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;

  const FlashSaleModel({
    required this.id,
    required this.productId,
    required this.originalPrice,
    required this.flashPrice,
    required this.flashStock,
    required this.soldCount,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    this.createdBy,
    this.createdAt,
  });

  int get stockLeft => (flashStock - soldCount).clamp(0, flashStock);
  bool get isSoldOut => stockLeft <= 0;

  double get discountPercent => originalPrice > 0
      ? ((originalPrice - flashPrice) / originalPrice * 100)
      : 0;

  FlashSaleStatus statusAt(DateTime now) {
    if (!isActive) return FlashSaleStatus.inactive;
    if (!endsAt.isAfter(now)) return FlashSaleStatus.ended;
    if (startsAt.isAfter(now)) return FlashSaleStatus.scheduled;
    if (isSoldOut) return FlashSaleStatus.soldOut;
    return FlashSaleStatus.running;
  }

  bool isRunningAt(DateTime now) => statusAt(now) == FlashSaleStatus.running;

  factory FlashSaleModel.fromMap(Map<String, dynamic> map) {
    DateTime parse(dynamic v, DateTime fallback) =>
        (v == null ? null : DateTime.tryParse(v.toString())?.toLocal()) ??
        fallback;
    final now = DateTime.now();
    return FlashSaleModel(
      id: map['id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      originalPrice: (map['original_price'] as num?)?.toDouble() ?? 0,
      flashPrice: (map['flash_price'] as num?)?.toDouble() ?? 0,
      flashStock: (map['flash_stock'] as num?)?.toInt() ?? 0,
      soldCount: (map['sold_count'] as num?)?.toInt() ?? 0,
      startsAt: parse(map['starts_at'], now),
      endsAt: parse(map['ends_at'], now),
      isActive: map['is_active'] as bool? ?? true,
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal()
          : null,
    );
  }
}
