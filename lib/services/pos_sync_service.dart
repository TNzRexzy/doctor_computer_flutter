import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/services/pos_local_database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PosSyncService {
  PosSyncService({
    Connectivity? connectivity,
    PosLocalDatabaseHelper? database,
    SupabaseClient? supabase,
  }) : _connectivity = connectivity ?? Connectivity(),
       _database = database ?? PosLocalDatabaseHelper.instance,
       _supabase = supabase ?? Supabase.instance.client;

  final Connectivity _connectivity;
  final PosLocalDatabaseHelper _database;
  final SupabaseClient _supabase;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  AuthProvider? _authProvider;
  Future<void>? _syncInProgress;

  Future<void> start(AuthProvider authProvider) async {
    if (_connectivitySubscription != null) return;
    _authProvider = authProvider;
    authProvider.addListener(_onAuthChanged);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (_hasNetwork(results)) scheduleSync();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[PosSyncService] Connectivity stream failed: $error');
      },
    );
    scheduleSync();
  }

  void _onAuthChanged() {
    if (_authProvider?.canWriteRemoteData == true &&
        _supabase.auth.currentUser != null) {
      scheduleSync();
    }
  }

  void scheduleSync() {
    unawaited(
      syncNow().catchError((Object error, StackTrace stackTrace) {
        debugPrint('[PosSyncService] Background sync failed: $error');
      }),
    );
  }

  Future<bool> hasNetworkConnection() async {
    try {
      return _hasNetwork(await _connectivity.checkConnectivity());
    } catch (error) {
      debugPrint('[PosSyncService] Connectivity check failed: $error');
      return false;
    }
  }

  Future<void> syncNow() {
    final running = _syncInProgress;
    if (running != null) return running;

    final future = _sync();
    _syncInProgress = future;
    return future.whenComplete(() => _syncInProgress = null);
  }

  Future<void> _sync() async {
    final user = _authProvider?.currentUser;
    if (_authProvider?.isOfflineSession == true ||
        _authProvider?.canWriteRemoteData != true ||
        (user?.role != UserRole.admin && user?.role != UserRole.cashier) ||
        _supabase.auth.currentUser == null) {
      return;
    }

    try {
      final connectivity = await _connectivity.checkConnectivity();
      if (!_hasNetwork(connectivity)) return;
    } catch (error) {
      debugPrint('[PosSyncService] Could not verify connectivity: $error');
      return;
    }

    try {
      await pullCatalog();
    } catch (error) {
      debugPrint('[PosSyncService] Catalog pull failed: $error');
    }

    try {
      await pullCashierShifts();
    } catch (error) {
      debugPrint('[PosSyncService] Cashier shift pull failed: $error');
    }

    if (_authProvider?.currentUser?.role == UserRole.admin) {
      try {
        await pullAdminSnapshot();
      } catch (error) {
        debugPrint('[PosSyncService] Admin snapshot pull failed: $error');
      }
    }

    await _pushAdminChanges(orderChanges: false);
    await _pushShifts();
    await _pushOrders();
    await _closeSyncedShifts();
    await _pushAdminChanges(orderChanges: true);

    try {
      await pullCatalog();
    } catch (error) {
      debugPrint('[PosSyncService] Catalog refresh failed: $error');
    }
  }

  Future<void> pullAdminSnapshot() async {
    if (_authProvider?.currentUser?.role != UserRole.admin ||
        _authProvider?.isOfflineSession == true ||
        _supabase.auth.currentUser == null) {
      return;
    }
    try {
      final users = await _supabase
          .from('users')
          .select('id, email, full_name, points, role, membership_tier');
      await _database.upsertAdminRecords(
        entity: 'users',
        records: users.map((row) => Map<String, dynamic>.from(row)).toList(),
      );
    } catch (error) {
      debugPrint('[PosSyncService] User snapshot pull failed: $error');
    }
    try {
      final vouchers = await _supabase
          .from('vouchers')
          .select()
          .order('created_at', ascending: false);
      await _database.upsertAdminRecords(
        entity: 'vouchers',
        records: vouchers.map((row) => Map<String, dynamic>.from(row)).toList(),
      );
    } catch (error) {
      debugPrint('[PosSyncService] Voucher snapshot pull failed: $error');
    }
    try {
      List<Map<String, dynamic>> orderRows;
      try {
        final response = await _supabase
            .from('orders')
            .select(
              'id, user_id, channel, status, total_price, order_date, created_at, '
              'payment_method, cashier_id, tracking_number, courier',
            )
            .order('created_at', ascending: false);
        orderRows = response.map(Map<String, dynamic>.from).toList();
      } catch (_) {
        final response = await _supabase
            .from('orders')
            .select(
              'id, user_id, channel, status, total_price, created_at, '
              'payment_method, cashier_id, tracking_number, courier',
            )
            .order('created_at', ascending: false);
        orderRows = response.map(Map<String, dynamic>.from).toList();
      }
      await _database.upsertAdminRecords(
        entity: 'orders',
        records: orderRows,
      );
    } catch (error) {
      debugPrint('[PosSyncService] Order snapshot pull failed: $error');
    }
    try {
      final flashSales = await _supabase.from('flash_sales').select();
      await _database.upsertAdminRecords(
        entity: 'flash_sales',
        records: flashSales.map((row) => Map<String, dynamic>.from(row)).toList(),
      );
    } catch (error) {
      debugPrint('[PosSyncService] Flash-sale snapshot pull failed: $error');
    }
    try {
      final shifts = await _supabase
          .from('cashier_shifts')
          .select(
            'id, cashier_id, opening_cash, total_sales, total_orders, '
            'closing_cash, variance, status, notes, opened_at, closed_at',
          )
          .order('opened_at', ascending: false)
          .limit(100);
      await _database.upsertAdminRecords(
        entity: 'cashier_shifts',
        records: shifts.map((row) => Map<String, dynamic>.from(row)).toList(),
      );
    } catch (error) {
      debugPrint('[PosSyncService] Shift snapshot pull failed: $error');
    }
  }

  Future<void> _pushAdminChanges({required bool orderChanges}) async {
    for (final change in await _database.readPendingAdminChanges()) {
        final operation = change['operation']?.toString() ?? '';
        final isOrderChange =
            operation == 'order_status' || operation == 'order_tracking';
        if (isOrderChange != orderChanges) continue;
        final id = change['id']?.toString() ?? '';
        final entity = change['entity']?.toString() ?? '';
        final recordId = change['record_id']?.toString() ?? '';
        try {
          final payload = Map<String, dynamic>.from(
            jsonDecode(change['payload_json']?.toString() ?? '{}') as Map,
          );
          if (operation == 'order_status') {
            await _supabase.rpc(
              'update_order_status',
              params: {
                'p_order_id': recordId,
                'p_status': payload['status'],
              },
            );
          } else if (operation == 'order_tracking') {
            await _supabase.rpc(
              'update_order_tracking',
              params: {
                'p_order_id': recordId,
                'p_courier': payload['courier'],
                'p_tracking_number': payload['tracking_number'],
              },
            );
          } else if (operation == 'delete') {
            switch (entity) {
              case 'products':
                await _supabase.from('products').delete().eq('id', recordId);
              case 'vouchers':
                await _supabase.from('vouchers').delete().eq('id', recordId);
              case 'flash_sales':
                await _supabase
                    .from('flash_sales')
                    .delete()
                    .eq('product_id', recordId);
              case 'categories':
                await _supabase.from('categories').delete().eq('id', recordId);
              default:
                throw StateError('Delete belum didukung untuk $entity.');
            }
          } else if (operation == 'upsert') {
            switch (entity) {
              case 'products':
                await _supabase.from('products').upsert(payload);
              case 'categories':
                await _supabase.from('categories').upsert(payload);
              case 'vouchers':
                await _supabase.from('vouchers').upsert(payload);
              case 'flash_sales':
                await _supabase
                    .from('flash_sales')
                    .upsert(payload, onConflict: 'product_id');
              case 'users':
                await _supabase.rpc(
                  'admin_update_user',
                  params: {
                    'p_user_id': recordId,
                    'p_full_name': payload['full_name'],
                    'p_points': payload['points'],
                    'p_role': payload['role'],
                    'p_membership_tier': payload['membership_tier'],
                  },
                );
              default:
                throw StateError('Upsert belum didukung untuk $entity.');
            }
          } else {
            throw StateError('Operasi sync admin tidak dikenal: $operation.');
          }
          await _database.markAdminChangeSynced(id);
        } catch (error) {
          debugPrint(
            '[PosSyncService] Admin change $id ($entity/$recordId) remains pending: $error',
          );
          await _database.setAdminChangeError(id, error.toString());
      }
    }
  }

  Future<void> pullCatalog() async {
    if (_authProvider?.isOfflineSession == true ||
        _supabase.auth.currentUser == null) {
      return;
    }

    final categoriesResponse = await _supabase.from('categories').select();
    final productsResponse = await _supabase.from('products').select();

    final categories = categoriesResponse
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final products = productsResponse
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    await _database.upsertCatalog(categories: categories, products: products);
  }

  Future<void> pullCashierShifts() async {
    final userId = _authProvider?.currentUser?.id;
    if (userId == null ||
        _authProvider?.isOfflineSession == true ||
        _supabase.auth.currentUser == null) {
      return;
    }
    final response = await _supabase
        .from('cashier_shifts')
        .select()
        .eq('cashier_id', userId)
        .order('opened_at', ascending: false)
        .limit(50);
    await _database.upsertRemoteShifts(
      response.map((row) => Map<String, dynamic>.from(row)).toList(),
    );
  }

  Future<void> _pushShifts() async {
    final shifts = await _database.readPendingShifts();
    for (final shift in shifts) {
      final localId = shift['id']?.toString() ?? '';
      try {
        var remoteId = shift['remote_id']?.toString();
        if (remoteId == null || remoteId.isEmpty) {
          final response = await _supabase.rpc(
            'sync_open_cashier_shift',
            params: {
              'p_local_shift_id': localId,
              'p_opening_cash': shift['opening_cash'],
              'p_notes': shift['notes'] ?? '',
            },
          );
          if (response is! Map || response['id'] == null) {
            throw const FormatException(
              'Invalid sync_open_cashier_shift response',
            );
          }
          remoteId = response['id'].toString();
          await _database.setShiftRemoteId(localId, remoteId);
        } else if (shift['status'] == 'open') {
          await _database.markShiftSynced(localId);
        }
      } catch (error) {
        debugPrint('[PosSyncService] Shift $localId remains pending: $error');
        await _database.setSyncError(
          table: 'local_cashier_shifts',
          id: localId,
          error: error.toString(),
        );
      }
    }
  }

  Future<void> _pushOrders() async {
    final orders = await _database.readPendingOrders();
    for (final order in orders) {
      final localId = order['id']?.toString() ?? '';
      final shiftId = order['shift_id']?.toString() ?? '';
      try {
        final shift = await _database.readShiftById(shiftId);
        final remoteShiftId = shift?['remote_id']?.toString();
        if (remoteShiftId == null || remoteShiftId.isEmpty) {
          throw StateError('Shift belum tersinkron; transaksi tetap pending.');
        }

        final items = await _database.readOrderItems(localId);
        final response = await _supabase.rpc(
          'sync_pos_order',
          params: {
            'p_local_order_id': localId,
            'p_local_shift_id': shiftId,
            'p_payment_method': order['payment_method'],
            'p_expected_total': order['total_price'],
            'p_items': items
                .map(
                  (item) => {
                    'product_id': item['product_id'],
                    'quantity': item['quantity'],
                  },
                )
                .toList(),
          },
        );
        if (response is! Map || response['id'] == null) {
          throw const FormatException('Invalid sync_pos_order response');
        }
        await _database.setOrderSynced(localId, response['id'].toString());
      } catch (error) {
        debugPrint('[PosSyncService] Order $localId remains pending: $error');
        await _database.setSyncError(
          table: 'local_orders',
          id: localId,
          error: error.toString(),
        );
      }
    }
  }

  Future<void> _closeSyncedShifts() async {
    final shifts = await _database.readPendingShifts();
    final pendingOrders = await _database.readPendingOrders();
    final shiftsWithPendingOrders = pendingOrders
        .map((order) => order['shift_id']?.toString())
        .whereType<String>()
        .toSet();

    for (final shift in shifts) {
      if (shift['status'] != 'closed') continue;
      final localId = shift['id']?.toString() ?? '';
      final remoteId = shift['remote_id']?.toString();
      if (remoteId == null || remoteId.isEmpty) continue;
      if (shiftsWithPendingOrders.contains(localId)) continue;

      try {
        await _supabase.rpc(
          'sync_close_cashier_shift',
          params: {
            'p_local_shift_id': localId,
            'p_closing_cash': shift['closing_cash'],
            'p_notes': shift['notes'] ?? '',
          },
        );
        await _database.markShiftSynced(localId);
      } catch (error) {
        debugPrint(
          '[PosSyncService] Shift close $localId remains pending: $error',
        );
        await _database.setSyncError(
          table: 'local_cashier_shifts',
          id: localId,
          error: error.toString(),
        );
      }
    }
  }

  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
