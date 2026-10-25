import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/remote/fake_remote_gateway.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';
import 'package:haqly_mobile/data/sync/pull.dart';
import 'package:haqly_mobile/data/sync/sync_service.dart';
import 'package:haqly_mobile/data/sync/sync_state.dart';
import 'package:haqly_mobile/data/sync/sync_state_notifier.dart';

void main() {
  const userId = '00000000-0000-0000-0000-000000000001';
  final baseTime = DateTime.utc(2026, 10, 24, 12, 0, 0);

  late AppDatabase db;
  late OutboxQueue outbox;
  late FakeRemoteGateway fakeRemote;
  late SyncService syncService;
  late PullService pullService;
  late SyncStateNotifier notifier;

  setUp(() {
    db = AppDatabase.inMemory();
    final clock = FixedClock(baseTime);
    outbox = OutboxQueue(db, clock: clock);
    fakeRemote = FakeRemoteGateway(
      isOnline: true,
      isAuthenticated: true,
      currentUserId: userId,
    );
    syncService = SyncService(
      db: db,
      outboxQueue: outbox,
      remoteGateway: fakeRemote,
      clock: clock,
    );
    pullService = PullService(
      db: db,
      outboxQueue: outbox,
      remoteGateway: fakeRemote,
    );
    notifier = SyncStateNotifier(
      outboxQueue: outbox,
      syncService: syncService,
      pullService: pullService,
      clock: clock,
    );
  });

  tearDown(() async {
    notifier.dispose();
    await db.close();
  });

  group('TASK-029: SyncStateNotifier - State Machine & Icon Visibility', () {
    test('initial state is idle, pending count is 0, and icon is hidden', () {
      expect(notifier.value.status, SyncStatus.idle);
      expect(notifier.value.pendingCount, 0);
      expect(notifier.value.isIconVisible, isFalse);
      expect(notifier.value.lastError, isNull);
    });

    test('pendingCount updates reactively from outbox stream', () async {
      await pumpEventQueue();
      expect(notifier.value.pendingCount, 0);

      await outbox.enqueue('expenses', 'exp-1');
      await pumpEventQueue();
      expect(notifier.value.pendingCount, 1);

      await outbox.enqueue('expenses', 'exp-2');
      await pumpEventQueue();
      expect(notifier.value.pendingCount, 2);

      await outbox.deleteByRow('expenses', 'exp-1');
      await pumpEventQueue();
      expect(notifier.value.pendingCount, 1);
    });

    test(
      'clean sync transitions idle -> syncing -> idle with icon hidden',
      () async {
        final stateHistory = <SyncStatus>[];
        notifier.addListener(() => stateHistory.add(notifier.value.status));

        await notifier.runSync();

        expect(stateHistory, [SyncStatus.syncing, SyncStatus.idle]);
        expect(notifier.value.status, SyncStatus.idle);
        expect(notifier.value.isIconVisible, isFalse);
        expect(notifier.value.lastSyncedAt, baseTime);
      },
    );

    test(
      'offline remote transitions idle -> syncing -> offline with icon visible',
      () async {
        fakeRemote.isOnline = false;

        final stateHistory = <SyncStatus>[];
        notifier.addListener(() => stateHistory.add(notifier.value.status));

        await notifier.runSync();

        expect(stateHistory, [SyncStatus.syncing, SyncStatus.offline]);
        expect(notifier.value.status, SyncStatus.offline);
        expect(notifier.value.isIconVisible, isTrue);
        expect(notifier.value.isOffline, isTrue);
        expect(notifier.value.canRetry, isTrue);
      },
    );

    test('sync failure transitions idle -> syncing -> error with error message and icon visible', () async {
      final nowIso = baseTime.toIso8601String();
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-fail',
              userId: const Value(userId),
              name: 'Lunch',
              amountMinor: 2000,
              localDate: '2026-10-24',
              createdAt: nowIso,
              clientUpdatedAt: nowIso,
            ),
          );
      await outbox.enqueue('expenses', 'exp-fail');
      await pumpEventQueue();

      fakeRemote.failForRowId = 'exp-fail';

      final stateHistory = <SyncStatus>[];
      notifier.addListener(() => stateHistory.add(notifier.value.status));

      await notifier.runSync();

      expect(stateHistory, [SyncStatus.syncing, SyncStatus.error]);
      expect(notifier.value.status, SyncStatus.error);
      expect(notifier.value.isIconVisible, isTrue);
      expect(notifier.value.hasError, isTrue);
      expect(notifier.value.lastError, contains('Sync failed for 1 item(s)'));
      expect(notifier.value.pendingCount, 1);
    });

    test(
      'tapToRetry resets backoff attempts and re-executes sync cleanly',
      () async {
        final nowIso = baseTime.toIso8601String();
        await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-retry',
                userId: const Value(userId),
                name: 'Dinner',
                amountMinor: 5000,
                localDate: '2026-10-24',
                createdAt: nowIso,
                clientUpdatedAt: nowIso,
              ),
            );
        final outboxId = await outbox.enqueue('expenses', 'exp-retry');
        await outbox.recordFailure(outboxId, error: 'Server 500');

        var entries = await outbox.getAllEntries();
        expect(entries.first.attempts, 1);

        // Server recovers
        fakeRemote.failForRowId = null;

        // User taps retry icon
        await notifier.tapToRetry();
        await pumpEventQueue();

        expect(notifier.value.status, SyncStatus.idle);
        expect(notifier.value.isIconVisible, isFalse);
        expect(notifier.value.pendingCount, 0);

        entries = await outbox.getAllEntries();
        expect(entries.isEmpty, isTrue);
      },
    );
  });
}
