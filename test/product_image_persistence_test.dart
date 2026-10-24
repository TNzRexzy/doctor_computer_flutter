import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_computer/data/models/product_model.dart';

void main() {
  const imageUrl =
      'https://example.supabase.co/storage/v1/object/public/assets/'
      'product-images/product-1/image.webp';

  final product = ProductModel(
    id: 'product-1',
    name: 'Test product',
    description: 'Test product',
    descriptionId: 'Test product',
    price: 100,
    categoryId: 'laptop',
    brand: 'Test',
    images: const [imageUrl],
    specs: const {},
    rating: 0,
    reviewCount: 0,
    stock: 1,
    isNew: true,
    isOnSale: false,
  );

  test('serializes uploaded image URLs to the database image_url array', () {
    expect(product.toMap()['image_url'], [imageUrl]);
  });

  test('restores image URLs from a Supabase product row', () {
    final restored = ProductModel.fromMap(product.toMap());

    expect(restored.images, [imageUrl]);
  });
}
