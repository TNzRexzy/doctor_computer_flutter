import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PosLocalDatabaseHelper {
  PosLocalDatabaseHelper._({this._databasePath});

  @visibleForTesting
  PosLocalDatabaseHelper.forTesting({required String databasePath})
    : this._(databasePath: databasePath);

  static final PosLocalDatabaseHelper instance = PosLocalDatabaseHelper._();

  static const int schemaVersion = 3;
  static const String databaseName = 'doctor_computer_pos.db';
  static const List<String> syncStatuses = [
    'pending_insert',
    'pending_update',
    'synced',
  ];

  Database? _database;
  Future<Database>? _openingDatabase;
  final String? _databasePath;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    final opening = _openingDatabase;
    if (opening != null) return opening;

    final future = _openDatabase();
    _openingDatabase = future;
    try {
      final database = await future;
      _database = database;
      return database;
    } finally {
      _openingDatabase = null;
    }
  }

  Future<void> upsertCatalog({
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> products,
  }) async {
    final db = await database;
    final cachedAt = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final pendingItemRows = await txn.rawQuery('''
      SELECT oi.product_id, SUM(oi.quantity) AS quantity
      FROM local_order_items oi
      JOIN local_orders o ON o.id = oi.order_id
      WHERE o.sync_status != 'synced' AND oi.product_id IS NOT NULL
      GROUP BY oi.product_id
    ''');
      final pendingQuantities = {
        for (final row in pendingItemRows)
          row['product_id'].toString(): _toInt(row['quantity']),
      };

      for (final category in categories) {
        final id = category['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final existing = await txn.query(
          'local_categories',
          columns: ['sync_status'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isNotEmpty && existing.first['sync_status'] != 'synced') {
          continue;
        }
        final values = {
          'id': id,
          'name': category['name']?.toString() ?? '',
          'name_id': category['name_id']?.toString(),
          'icon': category['icon']?.toString() ?? '',
          'product_count': _toInt(category['product_count']),
          'updated_at': category['updated_at']?.toString(),
          'cached_at': cachedAt,
          'sync_status': 'synced',
          'last_sync_error': null,
        };
        await txn.insert(
          'local_categories',
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.update(
          'local_categories',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      for (final product in products) {
        final id = product['id']?.toString();
        final name = product['name']?.toString();
        if (id == null || id.isEmpty || name == null) continue;
        final pendingDelete = await txn.query(
          'local_admin_outbox',
          columns: ['id'],
          where: "entity = ? AND record_id = ? AND operation = 'delete'",
          whereArgs: ['products', id],
          limit: 1,
        );
        if (pendingDelete.isNotEmpty) continue;
        final existing = await txn.query(
          'local_products',
          columns: ['sync_status'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isNotEmpty && existing.first['sync_status'] != 'synced') {
          continue;
        }
        final categoryId = product['category_id']?.toString();
        final categoryExists = categoryId == null || categoryId.isEmpty
            ? true
            : (await txn.query(
                'local_categories',
                columns: ['id'],
                where: 'id = ?',
                whereArgs: [categoryId],
                limit: 1,
              )).isNotEmpty;
        if (!categoryExists) {
          debugPrint(
            '[PosLocalDatabaseHelper] Product $id references uncached '
            'category $categoryId; caching product without category link.',
          );
        }
        await txn.insert('local_products', {
          'id': id,
          'name': name,
          'description': product['description']?.toString() ?? '',
          'description_id': product['description_id']?.toString(),
          'price_minor': _toMinor(product['price']),
          'original_price_minor': product['original_price'] == null
              ? null
              : _toMinor(product['original_price']),
          'category_id': categoryExists ? categoryId : null,
          'brand': product['brand']?.toString() ?? '',
          'image_url_json': jsonEncode(_stringList(product['image_url'])),
          'specs_json': jsonEncode(_stringMap(product['specs'])),
          'rating': _toDouble(product['rating']),
          'review_count': _toInt(product['review_count']),
          'stock': (_toInt(product['stock']) - (pendingQuantities[id] ?? 0))
              .clamp(0, 0x7fffffff),
          'is_new': _toBoolInt(product['is_new']),
          'is_on_sale': _toBoolInt(product['is_on_sale']),
          'created_at': product['created_at']?.toString(),
          'updated_at': product['updated_at']?.toString(),
          'cached_at': cachedAt,
          'sync_status': 'synced',
          'last_sync_error': null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final productIds = products
          .map((item) => item['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final cachedProducts = await txn.query(
        'local_products',
        columns: ['id', 'sync_status'],
      );
      for (final cachedProduct in cachedProducts) {
        final id = cachedProduct['id']?.toString();
        if (id != null &&
            !productIds.contains(id) &&
            cachedProduct['sync_status'] == 'synced') {
          await txn.delete('local_products', where: 'id = ?', whereArgs: [id]);
        }
      }

      final categoryIds = categories
          .map((item) => item['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final cachedCategories = await txn.query(
        'local_categories',
        columns: ['id', 'sync_status'],
      );
      for (final cachedCategory in cachedCategories) {
        final id = cachedCategory['id']?.toString();
        if (id != null &&
            !categoryIds.contains(id) &&
            cachedCategory['sync_status'] == 'synced') {
          await txn.delete(
            'local_categories',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> readCatalogProducts({
    String query = '',
  }) async {
    final db = await database;
    final normalizedQuery = query.trim();
    final rows = await db.query(
      'local_products',
      where: normalizedQuery.isEmpty
          ? null
          : 'name LIKE ? COLLATE NOCASE OR brand LIKE ? COLLATE NOCASE',
      whereArgs: normalizedQuery.isEmpty
          ? null
          : ['%$normalizedQuery%', '%$normalizedQuery%'],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(_productFromRow).toList();
  }

  Future<List<Map<String, dynamic>>> readCatalogCategories() async {
    final db = await database;
    return db.query('local_categories', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> saveLocalProduct(Map<String, dynamic> product) async {
    final id = product['id']?.toString();
    final name = product['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.trim().isEmpty) {
      throw ArgumentError('Produk harus memiliki id dan nama.');
    }

    final db = await database;
    await db.transaction((txn) async {
      final categoryId = product['category_id']?.toString();
      if (categoryId != null && categoryId.isNotEmpty) {
        final category = await txn.query(
          'local_categories',
          where: 'id = ?',
          whereArgs: [categoryId],
          limit: 1,
        );
        if (category.isEmpty) {
          throw StateError('Kategori produk belum tersedia di cache lokal.');
        }
      }

      final existing = await txn.query(
        'local_products',
        columns: ['sync_status'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final status = existing.isEmpty ? 'pending_insert' : 'pending_update';
      await txn.insert('local_products', {
        'id': id,
        'name': name.trim(),
        'description': product['description']?.toString() ?? '',
        'description_id': product['description_id']?.toString(),
        'price_minor': _toMinor(product['price']),
        'original_price_minor': product['original_price'] == null
            ? null
            : _toMinor(product['original_price']),
        'category_id': categoryId,
        'brand': product['brand']?.toString() ?? '',
        'image_url_json': jsonEncode(_stringList(product['image_url'])),
        'specs_json': jsonEncode(_stringMap(product['specs'])),
        'rating': _toDouble(product['rating']),
        'review_count': _toInt(product['review_count']),
        'stock': _toInt(product['stock']),
        'is_new': _toBoolInt(product['is_new']),
        'is_on_sale': _toBoolInt(product['is_on_sale']),
        'created_at': product['created_at']?.toString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
        'sync_status': status,
        'last_sync_error': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _enqueueChange(
        txn,
        entity: 'products',
        operation: 'upsert',
        recordId: id,
        payload: Map<String, dynamic>.from(product),
      );
    });
  }

  Future<void> deleteLocalProduct(String productId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'local_products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      await _enqueueChange(
        txn,
        entity: 'products',
        operation: 'delete',
        recordId: productId,
        payload: {'id': productId},
      );
    });
  }

  Future<void> upsertAdminRecords({
    required String entity,
    required List<Map<String, dynamic>> records,
  }) async {
    _validateAdminEntity(entity);
    final db = await database;
    final cachedAt = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final record in records) {
        final id = _adminRecordId(entity, record);
        if (id == null || id.isEmpty) continue;
        final hasPending = await txn.query(
          'local_admin_outbox',
          columns: ['id'],
          where: 'entity = ? AND record_id = ?',
          whereArgs: [entity, id],
          limit: 1,
        );
        if (hasPending.isNotEmpty) continue;
        await txn.insert('local_admin_records', {
          'entity': entity,
          'record_id': id,
          'data_json': jsonEncode(record),
          'sync_status': 'synced',
          'last_sync_error': null,
          'cached_at': cachedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> readAdminRecords(String entity) async {
    _validateAdminEntity(entity);
    final db = await database;
    final rows = await db.query(
      'local_admin_records',
      where: 'entity = ?',
      whereArgs: [entity],
      orderBy: 'cached_at DESC',
    );
    return rows.map((row) {
      final decoded = jsonDecode(row['data_json']! as String);
      return {
        ...Map<String, dynamic>.from(decoded as Map),
        'sync_status': row['sync_status'],
        'last_sync_error': row['last_sync_error'],
      };
    }).toList();
  }

  Future<void> queueAdminChange({
    required String entity,
    required String operation,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    _validateAdminEntity(entity);
    if (recordId.isEmpty ||
        !{
          'upsert',
          'delete',
          'order_status',
          'order_tracking',
        }.contains(operation)) {
      throw ArgumentError('Perubahan admin lokal tidak valid.');
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('local_admin_records', {
        'entity': entity,
        'record_id': recordId,
        'data_json': jsonEncode(payload),
        'sync_status':
            operation == 'upsert' &&
                (await txn.query(
                  'local_admin_records',
                  columns: ['record_id'],
                  where: 'entity = ? AND record_id = ?',
                  whereArgs: [entity, recordId],
                  limit: 1,
                )).isEmpty
            ? 'pending_insert'
            : 'pending_update',
        'last_sync_error': null,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (entity == 'orders' && operation == 'order_status') {
        await txn.update(
          'local_orders',
          {
            'status': payload['status']?.toString() ?? 'processing',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'id = ? OR remote_id = ?',
          whereArgs: [recordId, recordId],
        );
      }
      await _enqueueChange(
        txn,
        entity: entity,
        operation: operation,
        recordId: recordId,
        payload: payload,
      );
    });
  }

  Future<List<Map<String, dynamic>>> readPendingAdminChanges() async {
    final db = await database;
    return db.query('local_admin_outbox', orderBy: 'created_at ASC');
  }

  String generateLocalId() => _newUuid();

  Future<void> markAdminChangeSynced(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final changes = await txn.query(
        'local_admin_outbox',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (changes.isEmpty) return;
      final change = changes.first;
      final entity = change['entity'] as String;
      final recordId = change['record_id'] as String;
      final operation = change['operation'] as String;
      await txn.delete('local_admin_outbox', where: 'id = ?', whereArgs: [id]);
      final remaining = await txn.query(
        'local_admin_outbox',
        columns: ['id'],
        where: 'entity = ? AND record_id = ?',
        whereArgs: [entity, recordId],
        limit: 1,
      );

      if (entity == 'products') {
        if (operation == 'delete') return;
        await txn.update(
          'local_products',
          {
            'sync_status': remaining.isEmpty ? 'synced' : 'pending_update',
            'last_sync_error': null,
          },
          where: 'id = ?',
          whereArgs: [recordId],
        );
      } else {
        if (operation == 'delete') {
          await txn.delete(
            'local_admin_records',
            where: 'entity = ? AND record_id = ?',
            whereArgs: [entity, recordId],
          );
        } else {
          await txn.update(
            'local_admin_records',
            {
              'sync_status': remaining.isEmpty ? 'synced' : 'pending_update',
              'last_sync_error': null,
            },
            where: 'entity = ? AND record_id = ?',
            whereArgs: [entity, recordId],
          );
        }
      }
    });
  }

  Future<void> setAdminChangeError(String id, String error) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'local_admin_outbox',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      await txn.update(
        'local_admin_outbox',
        {'last_sync_error': error},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (row['entity'] == 'products') {
        await txn.update(
          'local_products',
          {'last_sync_error': error},
          where: 'id = ?',
          whereArgs: [row['record_id']],
        );
      } else {
        await txn.update(
          'local_admin_records',
          {'last_sync_error': error},
          where: 'entity = ? AND record_id = ?',
          whereArgs: [row['entity'], row['record_id']],
        );
      }
    });
  }

  Future<Map<String, dynamic>?> readOpenShift(String cashierId) async {
    final db = await database;
    final rows = await db.query(
      'local_cashier_shifts',
      where: 'cashier_id = ? AND status = ?',
      whereArgs: [cashierId, 'open'],
      limit: 1,
    );
    return rows.isEmpty ? null : _shiftFromRow(rows.first);
  }

  Future<List<Map<String, dynamic>>> readShiftHistory(
    String cashierId, {
    int limit = 20,
  }) async {
    final db = await database;
    final rows = await db.query(
      'local_cashier_shifts',
      where: 'cashier_id = ?',
      whereArgs: [cashierId],
      orderBy: 'opened_at DESC',
      limit: limit,
    );
    return rows.map(_shiftFromRow).toList();
  }

  Future<void> upsertRemoteShifts(List<Map<String, dynamic>> shifts) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final shift in shifts) {
        final remoteId = shift['id']?.toString();
        final cashierId = shift['cashier_id']?.toString();
        if (remoteId == null ||
            remoteId.isEmpty ||
            cashierId == null ||
            cashierId.isEmpty) {
          continue;
        }

        final existing = await txn.query(
          'local_cashier_shifts',
          where: 'remote_id = ? OR id = ?',
          whereArgs: [remoteId, remoteId],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

        if (shift['status'] == 'open') {
          final pendingLocalOpen = await txn.query(
            'local_cashier_shifts',
            where: 'cashier_id = ? AND status = ? AND remote_id IS NULL',
            whereArgs: [cashierId, 'open'],
            limit: 1,
          );
          if (pendingLocalOpen.isNotEmpty) continue;
        }

        final now = DateTime.now().toUtc().toIso8601String();
        await txn.insert('local_cashier_shifts', {
          'id': remoteId,
          'remote_id': remoteId,
          'cashier_id': cashierId,
          'opening_cash_minor': _toMinor(shift['opening_cash']),
          'total_sales_minor': _toMinor(shift['total_sales']),
          'total_orders': _toInt(shift['total_orders']),
          'closing_cash_minor': shift['closing_cash'] == null
              ? null
              : _toMinor(shift['closing_cash']),
          'variance_minor': shift['variance'] == null
              ? null
              : _toMinor(shift['variance']),
          'status': shift['status'] == 'closed' ? 'closed' : 'open',
          'notes': shift['notes']?.toString() ?? '',
          'opened_at': shift['opened_at']?.toString() ?? now,
          'closed_at': shift['closed_at']?.toString(),
          'sync_status': 'synced',
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<Map<String, dynamic>> createLocalShift({
    required String cashierId,
    required double openingCash,
    required String notes,
  }) async {
    if (cashierId.isEmpty || openingCash < 0) {
      throw ArgumentError('Kasir dan modal awal harus valid.');
    }

    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _newUuid();
    await db.insert('local_cashier_shifts', {
      'id': id,
      'cashier_id': cashierId,
      'opening_cash_minor': _toMinor(openingCash),
      'total_sales_minor': 0,
      'total_orders': 0,
      'status': 'open',
      'notes': notes,
      'opened_at': now,
      'sync_status': 'pending_insert',
      'created_at': now,
      'updated_at': now,
    });
    return (await readShiftById(id))!;
  }

  Future<Map<String, dynamic>> closeLocalShift({
    required String shiftId,
    required double closingCash,
    required String notes,
  }) async {
    if (closingCash < 0) throw ArgumentError('Uang penutupan tidak valid.');
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    return db.transaction((txn) async {
      final rows = await txn.query(
        'local_cashier_shifts',
        where: 'id = ? AND status = ?',
        whereArgs: [shiftId, 'open'],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Shift lokal terbuka tidak ditemukan.');
      }
      final shift = rows.first;
      final varianceMinor =
          _toMinor(closingCash) -
          _toInt(shift['opening_cash_minor']) -
          _toInt(shift['total_sales_minor']);
      final status = shift['remote_id'] == null
          ? 'pending_insert'
          : 'pending_update';
      await txn.update(
        'local_cashier_shifts',
        {
          'closing_cash_minor': _toMinor(closingCash),
          'variance_minor': varianceMinor,
          'status': 'closed',
          'notes': notes,
          'closed_at': now,
          'sync_status': status,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [shiftId],
      );
      final updated = await txn.query(
        'local_cashier_shifts',
        where: 'id = ?',
        whereArgs: [shiftId],
        limit: 1,
      );
      return _shiftFromRow(updated.first);
    });
  }

  Future<Map<String, dynamic>> createLocalPosOrder({
    required String cashierId,
    required String shiftId,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    double discountAmount = 0,
    String? voucherCode,
  }) async {
    if (items.isEmpty) throw ArgumentError('Keranjang POS kosong.');

    final db = await database;
    final orderId = _newUuid();
    final now = DateTime.now().toUtc().toIso8601String();
    return db.transaction((txn) async {
      final shifts = await txn.query(
        'local_cashier_shifts',
        where: 'id = ? AND cashier_id = ? AND status = ?',
        whereArgs: [shiftId, cashierId, 'open'],
        limit: 1,
      );
      if (shifts.isEmpty) {
        throw StateError('Buka shift kasir sebelum memproses transaksi.');
      }

      final mergedQuantities = <String, int>{};
      for (final item in items) {
        final productId = item['product_id']?.toString() ?? '';
        final quantity = _toInt(item['quantity']);
        if (productId.isEmpty || quantity < 1) {
          throw ArgumentError('Item keranjang tidak valid.');
        }
        mergedQuantities.update(
          productId,
          (existing) => existing + quantity,
          ifAbsent: () => quantity,
        );
      }

      final summary = <Map<String, dynamic>>[];
      var totalMinor = 0;
      for (final entry in mergedQuantities.entries) {
        final rows = await txn.query(
          'local_products',
          where: 'id = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError(
            'Produk ${entry.key} tidak tersedia di katalog lokal.',
          );
        }
        final product = rows.first;
        final stock = _toInt(product['stock']);
        if (stock < entry.value) {
          throw StateError(
            'Stok ${product['name']} tidak cukup. Stok lokal: $stock.',
          );
        }
        final priceMinor = _toInt(product['price_minor']);
        totalMinor += priceMinor * entry.value;
        summary.add({
          'product_id': entry.key,
          'product_name': product['name'],
          'product_price': priceMinor / 100,
          'product_image':
              _stringListFromJson(product['image_url_json']).firstOrNull ?? '',
          'category_id': product['category_id']?.toString() ?? '',
          'brand': product['brand']?.toString() ?? '',
          'unit_price': priceMinor / 100,
          'quantity': entry.value,
        });
        await txn.update(
          'local_products',
          {'stock': stock - entry.value, 'cached_at': now},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }

      final discountMinor = _toMinor(discountAmount);
      if (discountMinor < 0 || discountMinor > totalMinor) {
        throw ArgumentError('Diskon tidak valid.');
      }
      totalMinor -= discountMinor;
      await txn.insert('local_orders', {
        'id': orderId,
        'channel': 'pos',
        'cashier_id': cashierId,
        'shift_id': shiftId,
        'total_price_minor': totalMinor,
        'status': 'delivered',
        'order_date': now,
        'shipping_address': 'Ambil di Toko (POS Kasir)',
        'payment_method': paymentMethod,
        'items_summary_json': jsonEncode(summary),
        'voucher_code': voucherCode,
        'discount_amount_minor': discountMinor,
        'sync_status': 'pending_insert',
        'created_at': now,
        'updated_at': now,
      });

      for (final item in summary) {
        await txn.insert('local_order_items', {
          'id': _newUuid(),
          'order_id': orderId,
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'quantity': item['quantity'],
          'unit_price_minor': _toMinor(item['unit_price']),
          'product_snapshot_json': jsonEncode(item),
          'sync_status': 'pending_insert',
          'created_at': now,
          'updated_at': now,
        });
      }

      final shift = shifts.first;
      await txn.update(
        'local_cashier_shifts',
        {
          'total_sales_minor': _toInt(shift['total_sales_minor']) + totalMinor,
          'total_orders': _toInt(shift['total_orders']) + 1,
          'sync_status': shift['remote_id'] == null
              ? 'pending_insert'
              : 'pending_update',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [shiftId],
      );

      return {
        'id': orderId,
        'total_price': totalMinor / 100,
        'items': summary,
        'channel': 'pos',
        'status': 'delivered',
        'sync_status': 'pending_insert',
        'payment_method': paymentMethod,
        'order_date': now,
        'cashier_id': cashierId,
        'shift_id': shiftId,
      };
    });
  }

  Future<List<Map<String, dynamic>>> readLocalOrders({
    String? channel,
    int limit = 100,
  }) async {
    final db = await database;
    final rows = await db.query(
      'local_orders',
      where: channel == null ? null : 'channel = ?',
      whereArgs: channel == null ? null : [channel],
      orderBy: 'order_date DESC',
      limit: limit,
    );
    return rows.map(_orderFromRow).toList();
  }

  Future<List<Map<String, dynamic>>> readPendingShifts() async {
    final db = await database;
    final rows = await db.query(
      'local_cashier_shifts',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
      orderBy: 'created_at',
    );
    return rows.map(_shiftFromRow).toList();
  }

  Future<List<Map<String, dynamic>>> readPendingOrders() async {
    final db = await database;
    final rows = await db.query(
      'local_orders',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
      orderBy: 'created_at',
    );
    return rows.map(_orderFromRow).toList();
  }

  Future<List<Map<String, dynamic>>> readOrderItems(String orderId) async {
    final db = await database;
    final rows = await db.query(
      'local_order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at',
    );
    return rows.map(_itemFromRow).toList();
  }

  Future<void> setShiftRemoteId(String id, String remoteId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'local_cashier_shifts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      await txn.update(
        'local_cashier_shifts',
        {
          'remote_id': remoteId,
          'sync_status': row['status'] == 'closed'
              ? 'pending_update'
              : 'synced',
          'last_sync_error': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> markShiftSynced(String id) async {
    await _setSynced('local_cashier_shifts', id);
  }

  Future<void> setOrderSynced(String id, String remoteId) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'local_orders',
        {
          'remote_id': remoteId,
          'sync_status': 'synced',
          'last_sync_error': null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'local_order_items',
        {'sync_status': 'synced', 'last_sync_error': null, 'updated_at': now},
        where: 'order_id = ?',
        whereArgs: [id],
      );
      final pendingOrderChanges = await txn.query(
        'local_admin_outbox',
        where: "entity = 'orders' AND record_id = ?",
        whereArgs: [id],
      );
      if (pendingOrderChanges.isNotEmpty) {
        final cached = await txn.query(
          'local_admin_records',
          where: "entity = 'orders' AND record_id = ?",
          whereArgs: [id],
          limit: 1,
        );
        if (cached.isNotEmpty) {
          final payload = Map<String, dynamic>.from(
            jsonDecode(cached.first['data_json']! as String) as Map,
          )..['id'] = remoteId;
          await txn.delete(
            'local_admin_records',
            where: "entity = 'orders' AND record_id = ?",
            whereArgs: [id],
          );
          await txn.insert(
            'local_admin_records',
            {
              ...cached.first,
              'record_id': remoteId,
              'data_json': jsonEncode(payload),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final change in pendingOrderChanges) {
          final payload = Map<String, dynamic>.from(
            jsonDecode(change['payload_json']! as String) as Map,
          )..['id'] = remoteId;
          await txn.update(
            'local_admin_outbox',
            {
              'record_id': remoteId,
              'payload_json': jsonEncode(payload),
            },
            where: 'id = ?',
            whereArgs: [change['id']],
          );
        }
      }
    });
  }

  Future<void> setSyncError({
    required String table,
    required String id,
    required String error,
  }) async {
    const allowedTables = {
      'local_cashier_shifts',
      'local_orders',
      'local_order_items',
    };
    if (!allowedTables.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Unsupported sync table');
    }
    final db = await database;
    await db.update(
      table,
      {
        'last_sync_error': error,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (table == 'local_orders') {
      await db.update(
        'local_order_items',
        {
          'last_sync_error': error,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'order_id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<Map<String, dynamic>?> readShiftById(String id) async {
    final db = await database;
    final rows = await db.query(
      'local_cashier_shifts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _shiftFromRow(rows.first);
  }

  Future<void> _setSynced(String table, String id) async {
    const allowedTables = {'local_cashier_shifts'};
    if (!allowedTables.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Unsupported sync table');
    }
    final db = await database;
    await db.update(
      table,
      {
        'sync_status': 'synced',
        'last_sync_error': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Map<String, dynamic> _productFromRow(Map<String, Object?> row) => {
    ...row,
    'price': _toInt(row['price_minor']) / 100,
    'original_price': row['original_price_minor'] == null
        ? null
        : _toInt(row['original_price_minor']) / 100,
    'image_url': _stringListFromJson(row['image_url_json']),
    'specs': _stringMapFromJson(row['specs_json']),
    'is_new': _toInt(row['is_new']) == 1,
    'is_on_sale': _toInt(row['is_on_sale']) == 1,
  };

  Map<String, dynamic> _shiftFromRow(Map<String, Object?> row) => {
    ...row,
    'opening_cash': _toInt(row['opening_cash_minor']) / 100,
    'total_sales': _toInt(row['total_sales_minor']) / 100,
    'closing_cash': row['closing_cash_minor'] == null
        ? null
        : _toInt(row['closing_cash_minor']) / 100,
    'variance': row['variance_minor'] == null
        ? null
        : _toInt(row['variance_minor']) / 100,
  };

  Map<String, dynamic> _orderFromRow(Map<String, Object?> row) => {
    ...row,
    'total_price': _toInt(row['total_price_minor']) / 100,
    'discount_amount': _toInt(row['discount_amount_minor']) / 100,
    'items_summary': _stringMapListFromJson(row['items_summary_json']),
  };

  Map<String, dynamic> _itemFromRow(Map<String, Object?> row) => {
    ...row,
    'unit_price': _toInt(row['unit_price_minor']) / 100,
    'product_snapshot': _stringMapFromJson(row['product_snapshot_json']),
  };

  List<String> _stringList(dynamic value) {
    if (value is String) return [value];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const [];
  }

  List<String> _stringListFromJson(Object? value) {
    if (value is! String || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    return decoded is List
        ? decoded.map((item) => item.toString()).toList()
        : const [];
  }

  Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  Map<String, String> _stringMapFromJson(Object? value) {
    if (value is! String || value.isEmpty) return const {};
    final decoded = jsonDecode(value);
    return _stringMap(decoded);
  }

  List<Map<String, dynamic>> _stringMapListFromJson(Object? value) {
    if (value is! String || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _toMinor(dynamic value) => (_toDouble(value) * 100).round();

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toBoolInt(dynamic value) => value == true ? 1 : 0;

  String? _adminRecordId(String entity, Map<String, dynamic> record) {
    final value = switch (entity) {
      'flash_sales' => record['product_id'],
      _ => record['id'],
    };
    return value?.toString();
  }

  void _validateAdminEntity(String entity) {
    const allowed = {
      'users',
      'vouchers',
      'orders',
      'flash_sales',
      'cashier_shifts',
      'products',
      'categories',
    };
    if (!allowed.contains(entity)) {
      throw ArgumentError.value(entity, 'entity', 'Unsupported admin entity');
    }
  }

  Future<void> _enqueueChange(
    Transaction txn, {
    required String entity,
    required String operation,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    await txn.insert('local_admin_outbox', {
      'id': _newUuid(),
      'entity': entity,
      'operation': operation,
      'record_id': recordId,
      'payload_json': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'last_sync_error': null,
    });
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Database> _openDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'POS offline SQLite belum didukung pada Web. Gunakan Android, iOS, '
        'Windows, atau Linux.',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasePath =
        _databasePath ?? path.join(await getDatabasesPath(), databaseName);
    return openDatabase(
      databasePath,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_categories (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        name_id TEXT,
        icon TEXT NOT NULL DEFAULT '',
        product_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        cached_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced'
          CHECK (sync_status IN ('pending_insert', 'pending_update', 'synced')),
        last_sync_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE local_products (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        description_id TEXT,
        price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
        original_price_minor INTEGER,
        category_id TEXT,
        brand TEXT NOT NULL DEFAULT '',
        image_url_json TEXT NOT NULL DEFAULT '[]',
        specs_json TEXT NOT NULL DEFAULT '{}',
        rating REAL NOT NULL DEFAULT 0,
        review_count INTEGER NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL DEFAULT 0,
        is_new INTEGER NOT NULL DEFAULT 0 CHECK (is_new IN (0, 1)),
        is_on_sale INTEGER NOT NULL DEFAULT 0 CHECK (is_on_sale IN (0, 1)),
        created_at TEXT,
        updated_at TEXT,
        cached_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced'
          CHECK (sync_status IN ('pending_insert', 'pending_update', 'synced')),
        last_sync_error TEXT,
        FOREIGN KEY (category_id) REFERENCES local_categories(id)
          ON UPDATE CASCADE ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE local_cashier_shifts (
        id TEXT PRIMARY KEY NOT NULL,
        remote_id TEXT UNIQUE,
        cashier_id TEXT NOT NULL,
        opening_cash_minor INTEGER NOT NULL DEFAULT 0
          CHECK (opening_cash_minor >= 0),
        total_sales_minor INTEGER NOT NULL DEFAULT 0
          CHECK (total_sales_minor >= 0),
        total_orders INTEGER NOT NULL DEFAULT 0 CHECK (total_orders >= 0),
        closing_cash_minor INTEGER,
        variance_minor INTEGER,
        status TEXT NOT NULL DEFAULT 'open'
          CHECK (status IN ('open', 'closed')),
        notes TEXT NOT NULL DEFAULT '',
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending_insert'
          CHECK (sync_status IN ('pending_insert', 'pending_update', 'synced')),
        last_sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE local_orders (
        id TEXT PRIMARY KEY NOT NULL,
        remote_id TEXT UNIQUE,
        channel TEXT NOT NULL DEFAULT 'pos' CHECK (channel = 'pos'),
        user_id TEXT,
        cashier_id TEXT NOT NULL,
        shift_id TEXT,
        total_price_minor INTEGER NOT NULL CHECK (total_price_minor >= 0),
        status TEXT NOT NULL DEFAULT 'processing',
        order_date TEXT NOT NULL,
        shipping_address TEXT NOT NULL DEFAULT '',
        payment_method TEXT NOT NULL,
        items_summary_json TEXT NOT NULL DEFAULT '[]',
        voucher_code TEXT,
        discount_amount_minor INTEGER NOT NULL DEFAULT 0
          CHECK (discount_amount_minor >= 0),
        points_awarded INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending_insert'
          CHECK (sync_status IN ('pending_insert', 'pending_update', 'synced')),
        last_sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES local_cashier_shifts(id)
          ON UPDATE CASCADE ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE local_order_items (
        id TEXT PRIMARY KEY NOT NULL,
        order_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
        product_snapshot_json TEXT NOT NULL DEFAULT '{}',
        sync_status TEXT NOT NULL DEFAULT 'pending_insert'
          CHECK (sync_status IN ('pending_insert', 'pending_update', 'synced')),
        last_sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES local_orders(id)
          ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE local_admin_records (
        entity TEXT NOT NULL,
        record_id TEXT NOT NULL,
        data_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced'
          CHECK (sync_status IN ('pending_insert', 'pending_update', 'synced')),
        last_sync_error TEXT,
        cached_at TEXT NOT NULL,
        PRIMARY KEY (entity, record_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE local_admin_outbox (
        id TEXT PRIMARY KEY NOT NULL,
        entity TEXT NOT NULL,
        operation TEXT NOT NULL,
        record_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_sync_error TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_local_products_category ON local_products(category_id)',
    );
    await db.execute(
      'CREATE INDEX idx_local_products_name ON local_products(name COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX idx_local_orders_sync ON local_orders(sync_status, created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_local_order_items_order ON local_order_items(order_id)',
    );
    await db.execute(
      'CREATE INDEX idx_local_shifts_sync ON local_cashier_shifts(sync_status, created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_admin_outbox_order ON local_admin_outbox(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_admin_outbox_record '
      'ON local_admin_outbox(entity, record_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_one_open_shift_per_cashier '
      'ON local_cashier_shifts(cashier_id) WHERE status = \'open\'',
    );
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      await _createSchema(db, newVersion);
    }
    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        'local_cashier_shifts',
        'remote_id',
        'TEXT',
      );
      await _addColumnIfMissing(
        db,
        'local_cashier_shifts',
        'last_sync_error',
        'TEXT',
      );
      await _addColumnIfMissing(db, 'local_orders', 'remote_id', 'TEXT');
      await _addColumnIfMissing(db, 'local_orders', 'last_sync_error', 'TEXT');
      await _addColumnIfMissing(
        db,
        'local_order_items',
        'last_sync_error',
        'TEXT',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_local_shifts_remote_id '
        'ON local_cashier_shifts(remote_id)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_local_orders_remote_id '
        'ON local_orders(remote_id)',
      );
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(
        db,
        'local_categories',
        'sync_status',
        "TEXT NOT NULL DEFAULT 'synced'",
      );
      await _addColumnIfMissing(
        db,
        'local_categories',
        'last_sync_error',
        'TEXT',
      );
      await _addColumnIfMissing(
        db,
        'local_products',
        'sync_status',
        "TEXT NOT NULL DEFAULT 'synced'",
      );
      await _addColumnIfMissing(
        db,
        'local_products',
        'last_sync_error',
        'TEXT',
      );
      await db.execute('''
        CREATE TABLE local_admin_records (
          entity TEXT NOT NULL,
          record_id TEXT NOT NULL,
          data_json TEXT NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'synced',
          last_sync_error TEXT,
          cached_at TEXT NOT NULL,
          PRIMARY KEY (entity, record_id)
        )
      ''');
      await db.execute('''
        CREATE TABLE local_admin_outbox (
          id TEXT PRIMARY KEY NOT NULL,
          entity TEXT NOT NULL,
          operation TEXT NOT NULL,
          record_id TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          created_at TEXT NOT NULL,
          last_sync_error TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_admin_outbox_order ON local_admin_outbox(created_at)',
      );
      await db.execute(
        'CREATE INDEX idx_admin_outbox_record '
        'ON local_admin_outbox(entity, record_id)',
      );
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((item) => item['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  @visibleForTesting
  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
