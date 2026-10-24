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
}

/// Represents a component for building a PC.
class PcPartModel {
  final String id;
  final String name;
  final PcPartCategory category;
  final String brand;
  final double price;
  final Map<String, String> specs;
  final String? imageUrl;
  final List<String> compatibilityTags;

  const PcPartModel({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.price,
    required this.specs,
    this.imageUrl,
    required this.compatibilityTags,
  });
}
