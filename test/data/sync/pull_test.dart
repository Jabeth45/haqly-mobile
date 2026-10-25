import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/remote/fake_remote_gateway.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';
import 'package:haqly_mobile/data/sync/pull.dart';

void main() {
  const userId = '00000000-0000-0000-0000-000000000001';
  final baseTime = DateTime.utc(2026, 10, 24, 12, 0, 0);

  late AppDatabase db;
  late OutboxQueue outbox;
  late FakeRemoteGateway fakeRemote;
  late PullService pullService;

  setUp(() {
    db = AppDatabase.inMemory();
    outbox = OutboxQueue(db, clock: FixedClock(baseTime));
    fakeRemote = FakeRemoteGateway(
      isOnline: true,
      isAuthenticated: true,
      currentUserId: userId,
    );
    pullService = PullService(
      db: db,
      outboxQueue: outbox,
      remoteGateway: fakeRemote,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TASK-027: PullService - Cursor Tracking & Pagination', () {
    test('updates sync_meta cursors as remote records are pulled', () async {
      // Seed remote with 2 expenses having distinct updated_at timestamps
      final t1 = baseTime.add(const Duration(minutes: 1)).toIso8601String();
      final t2 = baseTime.add(const Duration(minutes: 2)).toIso8601String();

      await fakeRemote.upsert('expenses', {
        'id': 'exp-1',
        'user_id': userId,
        'name': 'Breakfast',
        'amount': 80.0,
        'category': 'Meals',
        'type': 'expense',
        'local_date': '2026-10-24',
        'created_at': t1,
        'client_updated_at': t1,
        'updated_at': t1,
      });

      await fakeRemote.upsert('expenses', {
        'id': 'exp-2',
        'user_id': userId,
        'name': 'Coffee',
        'amount': 45.0,
        'category': 'Meals',
        'type': 'expense',
        'local_date': '2026-10-24',
        'created_at': t2,
        'client_updated_at': t2,
        'updated_at': t2,
      });

      final result = await pullService.pull();
      expect(result.pulledCount, 2);
      expect(result.insertedCount, 2);

      // Verify cursor stored in sync_meta matches last record
      final meta = await (db.select(
        db.syncMeta,
      )..where((m) => m.recordTable.equals('expenses'))).getSingleOrNull();

      expect(meta, isNotNull);
      expect(meta!.cursorUpdatedAt, t2);
      expect(meta.cursorId, 'exp-2');

      // Subsequent pull fetches zero new rows
      final secondPull = await pullService.pull();
      expect(secondPull.pulledCount, 0);
    });

    test('paginates across multiple batches when page size is small', () async {
      // Seed remote with 5 contacts
      for (var i = 1; i <= 5; i++) {
        final timeIso = baseTime.add(Duration(minutes: i)).toIso8601String();
        await fakeRemote.upsert('contacts', {
          'id': 'cnt-$i',
          'user_id': userId,
          'name': 'Person $i',
          'created_at': timeIso,
          'client_updated_at': timeIso,
          'updated_at': timeIso,
        });
      }

      // Pull with batchSize = 2 to force 3 pages (2 + 2 + 1)
      final result = await pullService.pull(batchSize: 2);
      expect(result.pulledCount, 5);
      expect(result.insertedCount, 5);

      final localContacts = await db.select(db.contacts).get();
      expect(localContacts.length, 5);
    });

    test(
      'halts cleanly on offline without updating cursor past un-pulled records',
      () async {
        fakeRemote.isOnline = false;

        final result = await pullService.pull();
        expect(result.isOffline, isTrue);
        expect(result.pulledCount, 0);

        final metas = await db.select(db.syncMeta).get();
        expect(metas.isEmpty, isTrue);
      },
    );

    test('skips pull when unauthenticated', () async {
      fakeRemote.isAuthenticated = false;

      final result = await pullService.pull();
      expect(result.skippedUnauthenticated, isTrue);
      expect(result.pulledCount, 0);
    });
  });
}
