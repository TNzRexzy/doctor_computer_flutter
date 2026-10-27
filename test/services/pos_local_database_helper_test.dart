import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_computer/services/pos_local_database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late PosLocalDatabaseHelper database;

  setUp(() {
    database = PosLocalDatabaseHelper.forTesting(databasePath: ':memory:');
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'saves POS orders atomically and preserves pending stock on catalog pull',
    () async {
      await database.upsertCatalog(
        categories: [
          {'id': 'hardware', 'name': 'Hardware'},
        ],
        products: [
          {
            'id': 'product-1',
            'name': 'Keyboard',
            'category_id': 'hardware',
            'price': 120000,
            'stock': 5,
            'image_url': <String>[],
            'specs': <String, String>{},
          },
        ],
      );
      final shift = await database.createLocalShift(
        cashierId: 'cashier-1',
        openingCash: 100000,
        notes: 'Shift pagi',
      );

      await expectLater(
        database.createLocalPosOrder(
          cashierId: 'cashier-1',
          shiftId: shift['id'].toString(),
          paymentMethod: 'Cash',
          items: [
            {'product_id': 'product-1', 'quantity': 6},
          ],
        ),
        throwsStateError,
      );
      expect(await database.readLocalOrders(channel: 'pos'), isEmpty);
      expect((await database.readCatalogProducts()).single['stock'], 5);

      final order = await database.createLocalPosOrder(
        cashierId: 'cashier-1',
        shiftId: shift['id'].toString(),
        paymentMethod: 'Cash',
        items: [
          {'product_id': 'product-1', 'quantity': 2},
        ],
      );
      expect(order['total_price'], 240000);
      expect(order['sync_status'], 'pending_insert');
      expect(
        (await database.readOrderItems(order['id'].toString()))
            .single['quantity'],
        2,
      );
      expect(
        (await database.readOpenShift('cashier-1'))!['total_sales'],
        240000,
      );
      await database.queueAdminChange(
        entity: 'orders',
        operation: 'order_status',
        recordId: order['id'].toString(),
        payload: {...order, 'status': 'shipped'},
      );
      expect(
        (await database.readLocalOrders(channel: 'pos')).single['status'],
        'shipped',
      );

      await database.upsertCatalog(
        categories: [
          {'id': 'hardware', 'name': 'Hardware Updated'},
        ],
        products: [
          {
            'id': 'product-1',
            'name': 'Keyboard',
            'category_id': 'hardware',
            'price': 120000,
            'stock': 5,
            'image_url': <String>[],
            'specs': <String, String>{},
          },
        ],
      );
      final refreshedProduct = (await database.readCatalogProducts()).single;
      expect(refreshedProduct['stock'], 3);
      expect(refreshedProduct['category_id'], 'hardware');
      expect(
        (await database.readCatalogCategories()).single['name'],
        'Hardware Updated',
      );

      await database.setOrderSynced(order['id'].toString(), 'ORD-1');
      final pendingOrderChange =
          (await database.readPendingAdminChanges()).single;
      expect(pendingOrderChange['record_id'], 'ORD-1');
      await database.upsertCatalog(
        categories: [
          {'id': 'hardware', 'name': 'Hardware Updated'},
        ],
        products: [
          {
            'id': 'product-1',
            'name': 'Keyboard',
            'category_id': 'hardware',
            'price': 120000,
            'stock': 3,
            'image_url': <String>[],
            'specs': <String, String>{},
          },
        ],
      );
      expect((await database.readCatalogProducts()).single['stock'], 3);
      expect((await database.readPendingOrders()), isEmpty);
    },
  );

  test('preserves pending admin edits until sync succeeds', () async {
    await database.upsertAdminRecords(
      entity: 'users',
      records: [
        {
          'id': 'user-1',
          'full_name': 'Original Name',
          'points': 10,
          'role': 'client',
          'membership_tier': 'bronze',
        },
      ],
    );

    await database.queueAdminChange(
      entity: 'users',
      operation: 'upsert',
      recordId: 'user-1',
      payload: {
        'id': 'user-1',
        'full_name': 'Updated Name',
        'points': 50,
        'role': 'client',
        'membership_tier': 'silver',
      },
    );
    await database.upsertAdminRecords(
      entity: 'users',
      records: [
        {
          'id': 'user-1',
          'full_name': 'Original Name',
          'points': 10,
          'role': 'client',
          'membership_tier': 'bronze',
        },
      ],
    );

    final pendingUser = (await database.readAdminRecords('users')).single;
    expect(pendingUser['full_name'], 'Updated Name');
    expect(pendingUser['sync_status'], 'pending_update');
    final pendingChange = (await database.readPendingAdminChanges()).single;
    await database.setAdminChangeError(
      pendingChange['id'].toString(),
      'network unavailable',
    );
    expect(
      (await database.readAdminRecords('users')).single['last_sync_error'],
      'network unavailable',
    );

    await database.markAdminChangeSynced(pendingChange['id'].toString());
    expect(await database.readPendingAdminChanges(), isEmpty);
    final syncedUser = (await database.readAdminRecords('users')).single;
    expect(syncedUser['full_name'], 'Updated Name');
    expect(syncedUser['sync_status'], 'synced');
    expect(syncedUser['last_sync_error'], isNull);
  });
}
