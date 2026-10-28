import 'package:flutter/material.dart';

enum PcPartCategory { cpu, gpu, motherboard, ram, storage, psu, pcCase, cooler }

extension PcPartCategoryExtension on PcPartCategory {
  String get displayName {
    switch (this) {
      case PcPartCategory.cpu:
        return 'CPU';
      case PcPartCategory.gpu:
        return 'GPU';
      case PcPartCategory.motherboard:
        return 'Motherboard';
      case PcPartCategory.ram:
        return 'RAM';
      case PcPartCategory.storage:
        return 'Storage';
      case PcPartCategory.psu:
        return 'Power Supply';
      case PcPartCategory.pcCase:
        return 'Case';
      case PcPartCategory.cooler:
        return 'Cooler';
    }
  }

  String get displayNameId {
    switch (this) {
      case PcPartCategory.cpu:
        return 'Prosesor';
      case PcPartCategory.gpu:
        return 'Kartu Grafis';
      case PcPartCategory.motherboard:
        return 'Motherboard';
      case PcPartCategory.ram:
        return 'Memori RAM';
      case PcPartCategory.storage:
        return 'Penyimpanan';
      case PcPartCategory.psu:
        return 'Power Supply';
      case PcPartCategory.pcCase:
        return 'Casing PC';
      case PcPartCategory.cooler:
        return 'Pendingin';
    }
  }

  IconData get icon {
    switch (this) {
      case PcPartCategory.cpu:
        return Icons.memory;
      case PcPartCategory.gpu:
        return Icons.developer_board;
      case PcPartCategory.motherboard:
        return Icons.account_tree;
      case PcPartCategory.ram:
        return Icons.sd_storage;
      case PcPartCategory.storage:
        return Icons.storage;
      case PcPartCategory.psu:
        return Icons.power;
      case PcPartCategory.pcCase:
        return Icons.desktop_windows;
      case PcPartCategory.cooler:
        return Icons.ac_unit;
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
  final String? productId;
  final String? imageUrl;
  final List<String> compatibilityTags;

  const PcPartModel({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.price,
    required this.specs,
    this.productId,
    this.imageUrl,
    required this.compatibilityTags,
  });
}

class PcPartCompatibility {
  PcPartCompatibility._();

  static String? socketFor(PcPartModel? part) {
    if (part == null) return null;
    for (final tag in part.compatibilityTags) {
      final socket = _socketFromText(tag);
      if (socket != null) return socket;
    }
    return socketFromSpecifications(part.specs) ?? _socketFromText(part.name);
  }

  static String? socketFromSpecifications(Map<String, String> specs) {
    for (final entry in specs.entries) {
      if (!_isSocketSpec(entry.key)) continue;
      final socket = _socketFromText(entry.value);
      if (socket != null) return socket;
    }
    return null;
  }

  static String? memoryTypeFor(PcPartModel? part) {
    if (part == null) return null;
    for (final tag in part.compatibilityTags) {
      final memoryType = _memoryTypeFromText(tag);
      if (memoryType != null) return memoryType;
    }
    return memoryTypeFromSpecifications(part.specs) ??
        _memoryTypeFromText(part.name);
  }

  static String? memoryTypeFromSpecifications(Map<String, String> specs) {
    for (final entry in specs.entries) {
      if (!_isMemorySpec(entry.key)) continue;
      final memoryType = _memoryTypeFromText(entry.value);
      if (memoryType != null) return memoryType;
    }
    return null;
  }

  static List<String> tagsFor({
    required Map<String, String> specs,
    required Iterable<String> existingTags,
    String name = '',
  }) {
    final tags = existingTags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final socket = socketFromSpecifications(specs) ?? _socketFromText(name);
    final memoryType =
        memoryTypeFromSpecifications(specs) ?? _memoryTypeFromText(name);
    if (socket != null) tags.add('socket_${socket.toLowerCase()}');
    if (memoryType != null) tags.add(memoryType.toLowerCase());
    return tags.toList();
  }

  static Map<String, String> updateSpecifications({
    required Map<String, String> current,
    required bool includeSocket,
    required bool includeMemoryType,
    required String socket,
    required String memoryType,
  }) {
    final specs = Map<String, String>.from(current);
    specs.removeWhere((key, value) {
      if (_isSocketSpec(key)) return true;
      final isMemoryKey = _isMemorySpec(key);
      return isMemoryKey && _memoryTypeFromText(value) != null;
    });

    if (includeSocket && socket.trim().isNotEmpty) {
      specs['Socket'] = socket.trim();
    }
    if (includeMemoryType && memoryType.trim().isNotEmpty) {
      specs['Memory Type'] = memoryType.trim();
    }
    return specs;
  }

  static List<String> issues({
    PcPartModel? cpu,
    PcPartModel? motherboard,
    PcPartModel? ram,
  }) {
    final issues = <String>[];
    final cpuSocket = socketFor(cpu);
    final motherboardSocket = socketFor(motherboard);
    if (cpuSocket != null &&
        motherboardSocket != null &&
        cpuSocket != motherboardSocket) {
      issues.add(
        'Socket CPU ($cpuSocket) tidak cocok dengan motherboard '
        '($motherboardSocket).',
      );
    }

    final ramType = memoryTypeFor(ram);
    final motherboardMemoryType = memoryTypeFor(motherboard);
    if (ramType != null &&
        motherboardMemoryType != null &&
        ramType != motherboardMemoryType) {
      issues.add(
        'RAM $ramType tidak cocok dengan motherboard '
        '($motherboardMemoryType).',
      );
    }
    return issues;
  }

  static List<String> warnings({
    PcPartModel? cpu,
    PcPartModel? motherboard,
    PcPartModel? ram,
  }) {
    final warnings = <String>[];
    if (cpu != null &&
        motherboard != null &&
        (socketFor(cpu) == null || socketFor(motherboard) == null)) {
      warnings.add(
        'Socket CPU atau motherboard belum tercatat; kompatibilitas socket '
        'belum dapat dipastikan.',
      );
    }
    if (ram != null &&
        motherboard != null &&
        (memoryTypeFor(ram) == null || memoryTypeFor(motherboard) == null)) {
      warnings.add(
        'Tipe RAM atau dukungan RAM motherboard belum tercatat; '
        'kompatibilitas RAM belum dapat dipastikan.',
      );
    }
    return warnings;
  }

  static bool _isSocketSpec(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return normalized.contains('socket') || normalized == 'platform';
  }

  static bool _isMemorySpec(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return normalized.contains('memory') ||
        normalized.contains('ram') ||
        normalized == 'type';
  }

  static String? _socketFromText(String text) {
    final normalized = text.toLowerCase().replaceAll('_', ' ');
    final lga = RegExp(r'\blga[\s-]*(\d{3,5})\b').firstMatch(normalized);
    if (lga != null) return 'LGA ${lga.group(1)}';

    final amd = RegExp(r'\bam\s*([245])\b').firstMatch(normalized);
    if (amd != null) return 'AM${amd.group(1)}';

    final trx = RegExp(r'\bstrx\s*4\b').firstMatch(normalized);
    if (trx != null) return 'sTRX4';

    final tr = RegExp(r'\btr\s*4\b').firstMatch(normalized);
    if (tr != null) return 'TR4';
    return null;
  }

  static String? _memoryTypeFromText(String text) {
    final match = RegExp(
      r'\bddr\s*([345])\b',
      caseSensitive: false,
    ).firstMatch(text);
    return match == null ? null : 'DDR${match.group(1)}';
  }
}
