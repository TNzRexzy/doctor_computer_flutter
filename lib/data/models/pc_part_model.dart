import 'package:flutter/material.dart';

enum PcPartCategory { cpu, gpu, motherboard, ram, storage, psu, pcCase, cooler }

extension PcPartCategoryExtension on PcPartCategory {
  String get displayName {
    switch (this) {
      case PcPartCategory.cpu: return 'CPU';
      case PcPartCategory.gpu: return 'GPU';
      case PcPartCategory.motherboard: return 'Motherboard';
      case PcPartCategory.ram: return 'RAM';
      case PcPartCategory.storage: return 'Storage';
      case PcPartCategory.psu: return 'Power Supply';
      case PcPartCategory.pcCase: return 'Case';
      case PcPartCategory.cooler: return 'Cooler';
    }
  }

  String get displayNameId {
    switch (this) {
      case PcPartCategory.cpu: return 'Prosesor';
      case PcPartCategory.gpu: return 'Kartu Grafis';
      case PcPartCategory.motherboard: return 'Motherboard';
      case PcPartCategory.ram: return 'Memori RAM';
      case PcPartCategory.storage: return 'Penyimpanan';
      case PcPartCategory.psu: return 'Power Supply';
      case PcPartCategory.pcCase: return 'Casing PC';
      case PcPartCategory.cooler: return 'Pendingin';
    }
  }

  IconData get icon {
    switch (this) {
      case PcPartCategory.cpu: return Icons.memory;
      case PcPartCategory.gpu: return Icons.developer_board;
      case PcPartCategory.motherboard: return Icons.account_tree;
      case PcPartCategory.ram: return Icons.sd_storage;
      case PcPartCategory.storage: return Icons.storage;
      case PcPartCategory.psu: return Icons.power;
      case PcPartCategory.pcCase: return Icons.desktop_windows;
      case PcPartCategory.cooler: return Icons.ac_unit;
    }
  }

  String get dbCode {
    switch (this) {
      case PcPartCategory.cpu: return 'cpu';
      case PcPartCategory.gpu: return 'gpu';
      case PcPartCategory.motherboard: return 'motherboard';
      case PcPartCategory.ram: return 'ram';
      case PcPartCategory.storage: return 'storage';
      case PcPartCategory.psu: return 'psu';
      case PcPartCategory.pcCase: return 'pc_case';
      case PcPartCategory.cooler: return 'cooler';
    }
  }
}

/// Represents a component for building a PC matching the Supabase pc_parts table schema.
class PcPartModel {
  final String id;
  final String name;
  final PcPartCategory category;
  final String brand;
  final double price;
  final Map<String, String> specs;
  final String? imageUrl;
  final List<String> compatibilityTags;
  final String? sku;
  final String? brandCode;
  final String? subtype;
  final DateTime? createdAt;

  const PcPartModel({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.price,
    required this.specs,
    this.imageUrl,
    required this.compatibilityTags,
    this.sku,
    this.brandCode,
    this.subtype,
    this.createdAt,
  });

  PcPartModel copyWith({
    String? id,
    String? name,
    PcPartCategory? category,
    String? brand,
    double? price,
    Map<String, String>? specs,
    String? imageUrl,
    List<String>? compatibilityTags,
    String? sku,
    String? brandCode,
    String? subtype,
    DateTime? createdAt,
  }) {
    return PcPartModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      specs: specs ?? this.specs,
      imageUrl: imageUrl ?? this.imageUrl,
      compatibilityTags: compatibilityTags ?? this.compatibilityTags,
      sku: sku ?? this.sku,
      brandCode: brandCode ?? this.brandCode,
      subtype: subtype ?? this.subtype,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.dbCode,
      'brand': brand,
      'price': price,
      'specs': specs,
      'image_url': imageUrl,
      'compatibility_tags': compatibilityTags,
      if (sku != null) 'sku': sku,
      if (brandCode != null) 'brand_code': brandCode,
      if (subtype != null) 'subtype': subtype,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory PcPartModel.fromMap(Map<String, dynamic> map) {
    final catStr = (map['category']?.toString() ?? '').toLowerCase();
    PcPartCategory category = PcPartCategory.cpu;

    if (catStr == 'cat-001' || catStr == 'cpu' || catStr.contains('processor')) {
      category = PcPartCategory.cpu;
    } else if (catStr == 'cat-002' || catStr == 'gpu' || catStr.contains('vga') || catStr.contains('graphics')) {
      category = PcPartCategory.gpu;
    } else if (catStr == 'cat-003' || catStr == 'motherboard' || catStr.contains('mobo')) {
      category = PcPartCategory.motherboard;
    } else if (catStr == 'cat-004' || catStr == 'ram' || catStr.contains('memory')) {
      category = PcPartCategory.ram;
    } else if (catStr == 'cat-005' || catStr == 'storage' || catStr.contains('ssd') || catStr.contains('hdd')) {
      category = PcPartCategory.storage;
    } else if (catStr == 'cat-006' || catStr == 'psu' || catStr.contains('power')) {
      category = PcPartCategory.psu;
    } else if (catStr == 'cat-007' || catStr == 'cooler' || catStr.contains('cooling')) {
      category = PcPartCategory.cooler;
    } else if (catStr == 'cat-008' || catStr == 'pc_case' || catStr == 'case' || catStr.contains('casing')) {
      category = PcPartCategory.pcCase;
    }

    Map<String, String> specsMap = {};
    if (map['specs'] is Map) {
      specsMap = (map['specs'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    List<String> tags = [];
    if (map['compatibility_tags'] is List) {
      tags = (map['compatibility_tags'] as List).map((e) => e.toString()).toList();
    }

    return PcPartModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: category,
      brand: map['brand']?.toString() ?? 'Generic',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      specs: specsMap,
      imageUrl: map['image_url']?.toString(),
      compatibilityTags: tags,
      sku: map['sku']?.toString(),
      brandCode: map['brand_code']?.toString(),
      subtype: map['subtype']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }
}
