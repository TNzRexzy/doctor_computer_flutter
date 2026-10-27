import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/data/models/product_model.dart';

/// Jenis komponen PC yang otomatis dicatat ke tabel `pc_parts` saat admin /
/// kasir menambah produk baru.
///
/// [idPrefix]  -> awalan ID di `pc_parts.id` (cpu-001, gpu-001, ...).
/// [dbCategory]-> nilai kolom `pc_parts.category`. Semua nilai ini sudah
///                dikenali `PcBuilderProvider._mapPart`, jadi part langsung
///                muncul di halaman Rakit PC.
enum PcPartKind {
  cpu('cpu', 'cpu'),
  gpu('gpu', 'gpu'),
  motherboard('mobo', 'motherboard'),
  ram('ram', 'ram'),
  storage('storage', 'storage'), // SSD SATA, NVMe, HDD
  psu('psu', 'psu'),
  cooler('cooler', 'cooler'),
  pcCase('case', 'pc_case');

  const PcPartKind(this.idPrefix, this.dbCategory);
  final String idPrefix;
  final String dbCategory;
}

class PcPartSyncService {
  PcPartSyncService._();

  static const int _maxNameLength = 100;
  static const int _maxInsertAttempts = 4;

  /// Menentukan jenis komponen dari ID / nama kategori produk.
  /// Mengembalikan null jika kategori bukan komponen rakitan PC
  /// (laptop, monitor, keyboard, dll) sehingga tidak ikut ke `pc_parts`.
  static PcPartKind? resolveKind({
    required String categoryId,
    String? categoryName,
  }) {
    return _match(categoryId) ??
        (categoryName == null ? null : _match(categoryName));
  }

  static PcPartKind? _match(String raw) {
    final v = raw.toLowerCase().trim();
    if (v.isEmpty) return null;

    bool exact(List<String> options) => options.contains(v);
    bool has(List<String> words) => words.any(v.contains);

    if (exact(['cat-001', 'cpu']) || has(['processor', 'prosesor'])) {
      return PcPartKind.cpu;
    }
    if (exact(['cat-002', 'gpu']) ||
        has(['vga', 'graphics', 'graphic card', 'kartu grafis'])) {
      return PcPartKind.gpu;
    }
    if (exact(['cat-003', 'motherboard']) || has(['mobo', 'motherboard'])) {
      return PcPartKind.motherboard;
    }
    if (exact(['cat-004', 'ram']) || has(['memory', 'memori'])) {
      return PcPartKind.ram;
    }
    if (exact(['cat-005', 'storage']) ||
        has(['ssd', 'nvme', 'hdd', 'harddisk', 'hard disk', 'penyimpanan'])) {
      return PcPartKind.storage;
    }
    if (exact(['cat-006', 'psu']) ||
        has(['power supply', 'power_supply', 'powersupply'])) {
      return PcPartKind.psu;
    }
    if (exact(['cat-007', 'cooler']) || has(['cooler', 'cooling', 'pendingin'])) {
      return PcPartKind.cooler;
    }
    if (exact(['cat-008', 'case', 'pc_case']) ||
        has(['casing', 'pc case', 'pc_case'])) {
      return PcPartKind.pcCase;
    }
    return null;
  }

  /// Menambahkan [product] ke `pc_parts` dengan ID otomatis sesuai jenisnya
  /// (mis. `cpu-001`, `gpu-004`, `storage-012`).
  ///
  /// Mengembalikan ID yang dibuat, atau null jika produk bukan komponen PC.
  /// Melempar error jika insert gagal (supaya admin/kasir melihat pesannya).
  static Future<String?> insertForProduct(
    SupabaseClient client,
    ProductModel product, {
    String? categoryName,
  }) async {
    final kind = resolveKind(
      categoryId: product.categoryId,
      categoryName: categoryName,
    );
    if (kind == null) return null;

    final name = product.name.length > _maxNameLength
        ? product.name.substring(0, _maxNameLength)
        : product.name;
    final imageUrl = product.images.isNotEmpty ? product.images.first : null;

    Object? lastError;
    for (var attempt = 0; attempt < _maxInsertAttempts; attempt++) {
      final id = await _nextId(client, kind);
      try {
        await client.from('pc_parts').insert({
          'id': id,
          'name': name,
          'category': kind.dbCategory,
          'brand': product.brand,
          'price': product.price,
          'specs': product.specs,
          'image_url': imageUrl,
          'compatibility_tags': <String>[],
        });
        return id;
      } on PostgrestException catch (e) {
        // 23505 = ID bentrok (dua staff menambah part sejenis bersamaan).
        if (e.code == '23505') {
          lastError = e;
          continue;
        }
        rethrow;
      }
    }
    throw StateError(
      'Gagal membuat ID komponen ${kind.idPrefix} di pc_parts: $lastError',
    );
  }

  /// Membatalkan baris `pc_parts` bila penyimpanan produk gagal.
  static Future<void> rollback(SupabaseClient client, String? partId) async {
    if (partId == null) return;
    try {
      await client.from('pc_parts').delete().eq('id', partId);
    } catch (e) {
      debugPrint('Rollback pc_parts $partId gagal: $e');
    }
  }

  /// ID berikutnya untuk jenis [kind]: angka terbesar yang sudah ada + 1.
  static Future<String> _nextId(SupabaseClient client, PcPartKind kind) async {
    final prefix = kind.idPrefix;
    final rows = await client
        .from('pc_parts')
        .select('id')
        .like('id', '$prefix-%');

    final pattern = RegExp('^${RegExp.escape(prefix)}-(\\d+)\$');
    var maxNumber = 0;
    for (final row in rows) {
      final match = pattern.firstMatch(row['id']?.toString() ?? '');
      if (match == null) continue;
      final number = int.tryParse(match.group(1)!) ?? 0;
      if (number > maxNumber) maxNumber = number;
    }
    return '$prefix-${(maxNumber + 1).toString().padLeft(3, '0')}';
  }
}
