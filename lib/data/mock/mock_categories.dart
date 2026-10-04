import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/category_model.dart';

final List<CategoryModel> mockCategories = [
  const CategoryModel(id: 'laptop', name: 'Laptop', nameId: 'Laptop', icon: Icons.laptop_mac, productCount: 10),
  const CategoryModel(id: 'desktop', name: 'Desktop PC', nameId: 'PC Desktop', icon: Icons.desktop_windows, productCount: 5),
  const CategoryModel(id: 'monitor', name: 'Monitor', nameId: 'Monitor', icon: Icons.monitor, productCount: 6),
  const CategoryModel(id: 'keyboard', name: 'Keyboard', nameId: 'Keyboard', icon: Icons.keyboard, productCount: 6),
  const CategoryModel(id: 'mouse', name: 'Mouse', nameId: 'Mouse', icon: Icons.mouse, productCount: 6),
  const CategoryModel(id: 'headset', name: 'Headset', nameId: 'Headset', icon: Icons.headset, productCount: 5),
  const CategoryModel(id: 'storage', name: 'Storage', nameId: 'Penyimpanan', icon: Icons.storage, productCount: 6),
  const CategoryModel(id: 'networking', name: 'Networking', nameId: 'Jaringan', icon: Icons.router, productCount: 4),
];
