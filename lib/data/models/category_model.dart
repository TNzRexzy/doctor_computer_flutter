import 'package:flutter/widgets.dart';

/// Represents a product category.
class CategoryModel {
  final String id;
  final String name;
  final String nameId;
  final IconData icon;
  final int productCount;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.nameId,
    required this.icon,
    required this.productCount,
  });
}
