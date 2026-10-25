import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';

void main() {
  late AppDatabase db;
  late OutboxQueue queue;
  final baseTime = DateTime.utc(2026, 10, 24, 12, 0, 0);
  late FixedClock clock;

  setUp(() {
    db = AppDatabase.inMemory();
    clock = FixedClock(baseTime);
    queue = OutboxQueue(
      db,
      clock: clock,
      backoffPolicy: const BackoffPolicy(
        initialDelay: Duration(seconds: 2),
        multiplier: 2.0,
        maxDelay: Duration(seconds: 30),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TASK-025: OutboxQueue - Enqueue & Coalescing', () {
    test('enqueue inserts new outbox pointer atomically', () async {
      final id = await queue.enqueue('expenses', 'exp-1');

      final entries = await queue.getAllEntries();
      expect(entries.length, 1);
      final entry = entries.first;
      expect(entry.id, id);
      expect(entry.recordTable, 'expenses');
      expect(entry.rowId, 'exp-1');
      expect(entry.attempts, 0);
      expect(entry.lastError, isNull);
      expect(entry.createdAt, baseTime);
    });

    test(
      'enqueue distinct tables and rows creates distinct FIFO entries',
      () async {
        final id1 = await queue.enqueue('expenses', 'exp-1');
        final id2 = await queue.enqueue('ledger_entries', 'led-1');
        final id3 = await queue.enqueue('expenses', 'exp-2');

        final entries = await queue.getAllEntries();
        expect(entries.length, 3);
        expect(entries.map((e) => e.id).toList(), [id1, id2, id3]);
        expect(entries.map((e) => e.recordTable).toList(), [
          'expenses',
          'ledger_entries',
          'expenses',
        ]);
      },
    );

    test(
      'enqueue coalesces multiple writes to same row into one pointer',
      () async {
        final id1 = await queue.enqueue('expenses', 'exp-1');

        // Simulate failure on initial push
        await queue.recordFailure(id1, error: 'Network timeout 504');
        var entry = (await queue.getAllEntries()).first;
        expect(entry.attempts, 1);
        expect(entry.lastError, 'Network timeout 504');

        // New edit to same row occurs at later time
        final laterTime = baseTime.add(const Duration(seconds: 10));
        final id2 = await queue.enqueue('expenses', 'exp-1', now: laterTime);

        // Verify coalesced to same id, reset attempts, cleared error, updated timestamp
        expect(id2, id1);
        final entries = await queue.getAllEntries();
        expect(entries.length, 1);
        entry = entries.first;
        expect(entry.id, id1);
        expect(entry.attempts, 0);
        expect(entry.lastError, isNull);
        expect(entry.createdAt, laterTime);
      },
    );
  });

  group('TASK-025: OutboxQueue - Attempts & Exponential Backoff', () {
    test(
      'BackoffPolicy calculates exponential delays and respects ceiling cap',
      () {
        const policy = BackoffPolicy(
          initialDelay: Duration(seconds: 2),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 30),
        );

        // attempts == 0 -> immediately ready
        expect(policy.getDelay(0), Duration.zero);
        // attempt 1 failed -> initialDelay = 2s
        expect(policy.getDelay(1), const Duration(seconds: 2));
        // attempt 2 failed -> 2 * 2^1 = 4s
        expect(policy.getDelay(2), const Duration(seconds: 4));
        // attempt 3 failed -> 2 * 2^2 = 8s
        expect(policy.getDelay(3), const Duration(seconds: 8));
        // attempt 4 failed -> 2 * 2^3 = 16s
        expect(policy.getDelay(4), const Duration(seconds: 16));
        // attempt 5 failed -> 2 * 2^4 = 32s -> capped at 30s maxDelay
        expect(policy.getDelay(5), const Duration(seconds: 30));
        // attempt 10 failed -> capped at 30s
        expect(policy.getDelay(10), const Duration(seconds: 30));
      },
    );

    test('recordFailure increments attempts and updates lastError', () async {
      final id = await queue.enqueue('check_items', 'chk-1');

      await queue.recordFailure(
        id,
        error: 'SocketException: Connection refused',
      );
      var entry = (await queue.getAllEntries()).first;
      expect(entry.attempts, 1);
      expect(entry.lastError, 'SocketException: Connection refused');

      await queue.recordFailure(id, error: 'HTTP 500 Internal Server Error');
      entry = (await queue.getAllEntries()).first;
      expect(entry.attempts, 2);
      expect(entry.lastError, 'HTTP 500 Internal Server Error');
    });

    test('getReadyEntries filters out items still in backoff window', () async {
      final id1 = await queue.enqueue('expenses', 'exp-1'); // will fail
      final id2 = await queue.enqueue('expenses', 'exp-2'); // fresh

      // Record failure on id1 at T=0 (attempts=1 -> delay=2s)
      await queue.recordFailure(id1, error: 'Timeout', failedAt: baseTime);

      // At T=0, id1 is in backoff (needs 2s), id2 has attempts=0 so is ready
      var ready = await queue.getReadyEntries(now: baseTime);
      expect(ready.map((e) => e.id).toList(), [id2]);

      // At T=1s, id1 is still in backoff
      ready = await queue.getReadyEntries(
        now: baseTime.add(const Duration(seconds: 1)),
      );
      expect(ready.map((e) => e.id).toList(), [id2]);

      // At T=2s, id1 backoff elapsed -> both ready in FIFO order
      ready = await queue.getReadyEntries(
        now: baseTime.add(const Duration(seconds: 2)),
      );
      expect(ready.map((e) => e.id).toList(), [id1, id2]);
    });

    test(
      'resetAttempts immediately makes backed-off entries ready for retry',
      () async {
        final id = await queue.enqueue('contacts', 'cnt-1');
        await queue.recordFailure(id, error: 'Server unavailable');

        // Entry is in backoff at baseTime
        var ready = await queue.getReadyEntries(now: baseTime);
        expect(ready.isEmpty, isTrue);

        // User triggers tap-to-retry
        await queue.resetAttempts();

        final entries = await queue.getAllEntries();
        expect(entries.first.attempts, 0);
        expect(entries.first.lastError, isNull);

        ready = await queue.getReadyEntries(now: baseTime);
        expect(ready.length, 1);
        expect(ready.first.id, id);
      },
    );
  });

  group('TASK-025: OutboxQueue - Deletion on Sync Success', () {
    test('deleteEntry removes entry by primary key', () async {
      final id1 = await queue.enqueue('budgets', 'bgt-1');
      final id2 = await queue.enqueue('budgets', 'bgt-2');

      final deleted = await queue.deleteEntry(id1);
      expect(deleted, isTrue);

      final remaining = await queue.getAllEntries();
      expect(remaining.length, 1);
      expect(remaining.first.id, id2);
    });

    test('deleteByRow removes entries matching tableName and rowId', () async {
      await queue.enqueue('user_categories', 'cat-1');
      await queue.enqueue('user_categories', 'cat-2');

      final count = await queue.deleteByRow('user_categories', 'cat-1');
      expect(count, 1);

      final remaining = await queue.getAllEntries();
      expect(remaining.length, 1);
      expect(remaining.first.rowId, 'cat-2');
    });
  });

  group('TASK-025: OutboxQueue - Counts & Reactive Stream', () {
    test(
      'watchPendingCount emits real-time updates on queue modifications',
      () async {
        final counts = <int>[];
        final subscription = queue.watchPendingCount().listen(counts.add);

        await pumpEventQueue();
        expect(counts, [0]);

        final id1 = await queue.enqueue('expenses', 'exp-1');
        await pumpEventQueue();
        expect(counts, [0, 1]);

        final id2 = await queue.enqueue('expenses', 'exp-2');
        await pumpEventQueue();
        expect(counts, [0, 1, 2]);

        // Coalescing edit does not change count
        await queue.enqueue('expenses', 'exp-1');
        await pumpEventQueue();
        expect(counts.length, 3); // no new count event because count remains 2

        // Delete an entry
        await queue.deleteEntry(id1);
        await pumpEventQueue();
        expect(counts, [0, 1, 2, 1]);

        await queue.deleteEntry(id2);
        await pumpEventQueue();
        expect(counts, [0, 1, 2, 1, 0]);

        await subscription.cancel();
      },
    );
  });

  group('TASK-025: OutboxQueue - Crash Safety & Transaction Rollback', () {
    test(
      'transaction rollback leaves outbox in consistent previous state',
      () async {
        await queue.enqueue('expenses', 'exp-safe');

        final countBefore = await queue.getPendingCount();
        expect(countBefore, 1);

        // Simulate a multi-table business operation that throws midway
        try {
          await db.transaction(() async {
            // 1. Enqueue outbox pointer
            await queue.enqueue('expenses', 'exp-failed-crash');

            // 2. Simulate unhandled crash before commit
            throw StateError(
              'Simulated crash / disk full midway through write',
            );
          });
        } catch (e) {
          expect(e, isA<StateError>());
        }

        // Verify that outbox rolled back to original 1 item and no corrupt pointer remains
        final countAfter = await queue.getPendingCount();
        expect(countAfter, 1);

        final entries = await queue.getAllEntries();
        expect(entries.length, 1);
        expect(entries.first.rowId, 'exp-safe');
      },
    );
  });
}
