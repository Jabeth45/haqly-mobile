import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/remote/fake_remote_gateway.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';
import 'package:haqly_mobile/data/sync/sync_service.dart';

class MutableClock extends Clock {
  MutableClock(this.current);
  DateTime current;

  @override
  DateTime now() => current;
}

void main() {
  late AppDatabase db;
  late OutboxQueue outboxQueue;
  late FakeRemoteGateway fakeRemote;
  late SyncService syncService;
  late MutableClock clock;
  final baseTime = DateTime.utc(2026, 10, 24, 12, 0, 0);
  const testUserId = '00000000-0000-0000-0000-000000000001';

  setUp(() {
    db = AppDatabase.inMemory();
    clock = MutableClock(baseTime);
    outboxQueue = OutboxQueue(
      db,
      clock: clock,
      backoffPolicy: const BackoffPolicy(
        initialDelay: Duration(seconds: 2),
        multiplier: 2.0,
        maxDelay: Duration(seconds: 30),
      ),
    );
    fakeRemote = FakeRemoteGateway(
      isOnline: true,
      isAuthenticated: true,
      currentUserId: testUserId,
    );
    syncService = SyncService(
      db: db,
      outboxQueue: outboxQueue,
      remoteGateway: fakeRemote,
      clock: clock,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedAllTables() async {
    final nowIso = baseTime.toIso8601String();

    await db
        .into(db.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'exp-1',
            userId: const Value(testUserId),
            name: 'Lunch',
            amountMinor: 25000, // 250.00
            localDate: '2026-10-24',
            createdAt: nowIso,
            clientUpdatedAt: nowIso,
          ),
        );
    await outboxQueue.enqueue('expenses', 'exp-1');

    await db
        .into(db.checkItems)
        .insert(
          CheckItemsCompanion.insert(
            id: 'chk-1',
            userId: const Value(testUserId),
            name: 'Coffee Maker',
            priceMinor: 500000, // 5000.00
            uses: 100.0,
            verdict: 'worth',
            regretLevel: 1,
            localDate: '2026-10-24',
            createdAt: nowIso,
            clientUpdatedAt: nowIso,
          ),
        );
    await outboxQueue.enqueue('check_items', 'chk-1');

    await db
        .into(db.ledgerEntries)
        .insert(
          LedgerEntriesCompanion.insert(
            id: 'led-1',
            userId: const Value(testUserId),
            person: 'Abebe',
            amountMinor: 100000, // 1000.00
            type: 'lent',
            localDate: '2026-10-24',
            createdAt: nowIso,
            clientUpdatedAt: nowIso,
          ),
        );
    await outboxQueue.enqueue('ledger_entries', 'led-1');

    await db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'bgt-1',
            userId: testUserId,
            monthlyMinor: const Value(1500000), // 15000.00
            updatedAt: nowIso,
            clientUpdatedAt: nowIso,
          ),
        );
    await outboxQueue.enqueue('budgets', 'bgt-1');

    await db
        .into(db.contacts)
        .insert(
          ContactsCompanion.insert(
            id: 'cnt-1',
            userId: const Value(testUserId),
            name: 'Almaz',
            createdAt: nowIso,
            clientUpdatedAt: nowIso,
          ),
        );
    await outboxQueue.enqueue('contacts', 'cnt-1');

    await db
        .into(db.userCategories)
        .insert(
          UserCategoriesCompanion.insert(
            id: 'cat-1',
            userId: const Value(testUserId),
            name: 'Gadgets',
            kind: 'expense',
            createdAt: nowIso,
            clientUpdatedAt: nowIso,
          ),
        );
    await outboxQueue.enqueue('user_categories', 'cat-1');
  }

  group('TASK-026: SyncService Drain - Clean Push Across All Tables', () {
    test('drain pushes all 6 tables and clears outbox completely', () async {
      await seedAllTables();
      expect(await outboxQueue.getPendingCount(), 6);

      final result = await syncService.drain();

      expect(result.attemptedCount, 6);
      expect(result.successCount, 6);
      expect(result.failureCount, 0);
      expect(result.isOffline, isFalse);

      // Verify outbox completely drained
      expect(await outboxQueue.getPendingCount(), 0);

      // Verify remote received all records
      expect(fakeRemote.rowsFor('expenses').length, 1);
      expect(fakeRemote.rowsFor('expenses').first['amount'], 250.00);

      expect(fakeRemote.rowsFor('check_items').length, 1);
      expect(fakeRemote.rowsFor('check_items').first['price'], 5000.00);

      expect(fakeRemote.rowsFor('ledger_entries').length, 1);
      expect(fakeRemote.rowsFor('ledger_entries').first['amount'], 1000.00);

      expect(fakeRemote.rowsFor('budgets').length, 1);
      expect(fakeRemote.rowsFor('budgets').first['monthly_budget'], 15000.00);

      expect(fakeRemote.rowsFor('contacts').length, 1);
      expect(fakeRemote.rowsFor('contacts').first['name'], 'Almaz');

      expect(fakeRemote.rowsFor('user_categories').length, 1);
      expect(fakeRemote.rowsFor('user_categories').first['name'], 'Gadgets');
    });
  });

  group('TASK-026: SyncService Drain - Offline Handling', () {
    test('drain halts on offline without corrupting outbox entries', () async {
      await seedAllTables();
      fakeRemote.isOnline = false;

      final result = await syncService.drain();

      expect(result.isOffline, isTrue);
      expect(result.successCount, 0);

      // Outbox entries preserved with 0 attempts (network unavailable, not row failure)
      final pending = await outboxQueue.getAllEntries();
      expect(pending.length, 6);
      expect(pending.every((e) => e.attempts == 0), isTrue);
    });
  });

  group('TASK-026: SyncService Drain - Partial Failure & Retry Backoff', () {
    test('partial failure increments attempts for failed row while succeeding for others', () async {
      final nowIso = baseTime.toIso8601String();
      for (final id in ['exp-1', 'exp-2', 'exp-3']) {
        await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: id,
                userId: const Value(testUserId),
                name: 'Item $id',
                amountMinor: 1000,
                localDate: '2026-10-24',
                createdAt: nowIso,
                clientUpdatedAt: nowIso,
              ),
            );
        await outboxQueue.enqueue('expenses', id);
      }

      // Configure exp-2 to fail
      fakeRemote.failForRowId = 'exp-2';

      final result = await syncService.drain();

      expect(result.attemptedCount, 3);
      expect(result.successCount, 2);
      expect(result.failureCount, 1);

      // Verify only exp-2 remains in outbox with attempts=1
      final remaining = await outboxQueue.getAllEntries();
      expect(remaining.length, 1);
      expect(remaining.first.rowId, 'exp-2');
      expect(remaining.first.attempts, 1);
      expect(
        remaining.first.lastError,
        contains('Simulated persistent failure'),
      );

      // Verify remote received exp-1 and exp-3
      final pushedExpenses = fakeRemote.rowsFor('expenses');
      expect(pushedExpenses.map((r) => r['id']).toSet(), {'exp-1', 'exp-3'});
    });

    test(
      'retries failed item after backoff duration elapses and succeeds',
      () async {
        final nowIso = baseTime.toIso8601String();
        await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-retry',
                userId: const Value(testUserId),
                name: 'Retry Item',
                amountMinor: 5000,
                localDate: '2026-10-24',
                createdAt: nowIso,
                clientUpdatedAt: nowIso,
              ),
            );
        await outboxQueue.enqueue('expenses', 'exp-retry');

        // 1. Initial drain fails once
        fakeRemote.failForRowId = 'exp-retry';
        var result = await syncService.drain();
        expect(result.failureCount, 1);

        // 2. Immediate drain skips it because it is in 2s backoff window
        fakeRemote.failForRowId = null; // server recovered
        result = await syncService.drain();
        expect(result.attemptedCount, 0); // skipped due to backoff

        // 3. Advance time by 3 seconds past backoff window
        clock.current = baseTime.add(const Duration(seconds: 3));

        // 4. Drain again; item is ready and succeeds
        result = await syncService.drain();
        expect(result.successCount, 1);
        expect(result.failureCount, 0);
        expect(await outboxQueue.getPendingCount(), 0);
        expect(fakeRemote.rowsFor('expenses').length, 1);
      },
    );
  });

  group('TASK-026: SyncService Drain - Guest Sentinel & Stale Pointers', () {
    test('skips rows with user_id LOCAL until identity adoption', () async {
      final nowIso = baseTime.toIso8601String();
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-guest',
              userId: const Value('LOCAL'),
              name: 'Guest Coffee',
              amountMinor: 3000,
              localDate: '2026-10-24',
              createdAt: nowIso,
              clientUpdatedAt: nowIso,
            ),
          );
      await outboxQueue.enqueue('expenses', 'exp-guest');

      final result = await syncService.drain();

      expect(result.attemptedCount, 0);
      expect(fakeRemote.rowsFor('expenses').isEmpty, isTrue);
      // Outbox pointer preserved for post-adoption drain
      expect(await outboxQueue.getPendingCount(), 1);
    });

    test('skips drain completely when client is unauthenticated', () async {
      await seedAllTables();
      fakeRemote.isAuthenticated = false;

      final result = await syncService.drain();

      expect(result.skippedUnauthenticated, isTrue);
      expect(result.attemptedCount, 0);
      expect(await outboxQueue.getPendingCount(), 6);
    });

    test(
      'stale outbox pointers to non-existent rows are safely discarded',
      () async {
        // Enqueue pointer without inserting corresponding row in SQLite
        await outboxQueue.enqueue('expenses', 'ghost-row-id');

        final result = await syncService.drain();

        expect(result.successCount, 0);
        expect(result.failureCount, 0);
        // Ghost pointer discarded
        expect(await outboxQueue.getPendingCount(), 0);
      },
    );
  });
}
