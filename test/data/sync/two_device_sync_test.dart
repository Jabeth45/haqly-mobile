import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' hide Expense, Contact;
import 'package:haqly_mobile/data/remote/fake_remote_gateway.dart';
import 'package:haqly_mobile/data/repositories/contact_repository.dart';
import 'package:haqly_mobile/data/repositories/expense_repository.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';
import 'package:haqly_mobile/data/sync/pull.dart';
import 'package:haqly_mobile/data/sync/sync_service.dart';
import 'package:haqly_mobile/domain/models/contact.dart';
import 'package:haqly_mobile/domain/models/expense.dart';
import 'package:haqly_mobile/domain/money.dart';

class TestDevice {
  TestDevice({
    required this.name,
    required this.remote,
    required this.baseTime,
  }) {
    db = AppDatabase.inMemory();
    clock = MutableClock(baseTime);
    outbox = OutboxQueue(db, clock: clock);
    syncService = SyncService(
      db: db,
      outboxQueue: outbox,
      remoteGateway: remote,
      clock: clock,
    );
    pullService = PullService(
      db: db,
      outboxQueue: outbox,
      remoteGateway: remote,
    );
    expenseRepo = DriftExpenseRepository(db, clock: clock);
    contactRepo = DriftContactRepository(db, clock: clock);
  }

  final String name;
  final FakeRemoteGateway remote;
  final DateTime baseTime;

  late final AppDatabase db;
  late final MutableClock clock;
  late final OutboxQueue outbox;
  late final SyncService syncService;
  late final PullService pullService;
  late final ExpenseRepository expenseRepo;
  late final ContactRepository contactRepo;

  Future<void> dispose() async {
    await db.close();
  }
}

class MutableClock extends Clock {
  MutableClock(this.current);
  DateTime current;

  @override
  DateTime now() => current;
}

void main() {
  const userId = '00000000-0000-0000-0000-000000000001';
  final t0 = DateTime.utc(2026, 10, 24, 12, 0, 0);

  late FakeRemoteGateway sharedRemote;
  late TestDevice deviceA;
  late TestDevice deviceB;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    sharedRemote = FakeRemoteGateway(
      isOnline: true,
      isAuthenticated: true,
      currentUserId: userId,
    );
    deviceA = TestDevice(name: 'DeviceA', remote: sharedRemote, baseTime: t0);
    deviceB = TestDevice(name: 'DeviceB', remote: sharedRemote, baseTime: t0);
  });

  tearDown(() async {
    await deviceA.dispose();
    await deviceB.dispose();
  });

  group(
    'TASK-027: Two-Device Sync - M5: Last-Write-Wins Conflict Resolution',
    () {
      test('concurrent offline edits on two devices resolve to newer client_updated_at without duplicates', () async {
        // 1. Device A creates an expense at T=0
        final initialExpense = Expense(
          id: 'exp-shared-1',
          userId: userId,
          name: 'Lunch with Abebe',
          amount: const Money.fromMinorUnits(20000), // 200.00
          category: 'Meals',
          localDate: '2026-10-24',
          createdAt: t0,
          clientUpdatedAt: t0,
        );
        await deviceA.expenseRepo.save(initialExpense);

        // Device A pushes to remote
        final drainA1 = await deviceA.syncService.drain();
        expect(drainA1.successCount, 1);

        // 2. Device B pulls from remote
        final pullB1 = await deviceB.pullService.pull();
        expect(pullB1.pulledCount, 1);
        final expenseOnB = await deviceB.expenseRepo.getById(
          'exp-shared-1',
          userId: userId,
        );
        expect(expenseOnB, isNotNull);
        expect(expenseOnB!.name, 'Lunch with Abebe');
        expect(expenseOnB.amount.minorUnits, 20000);

        // 3. Both devices go offline
        sharedRemote.isOnline = false;

        // 4. Device A makes an edit at T=10s
        final t10 = t0.add(const Duration(seconds: 10));
        deviceA.clock.current = t10;
        final editA = expenseOnB.copyWith(
          name: 'Device A Lunch Edit',
          amount: const Money.fromMinorUnits(28000), // 280.00
          clientUpdatedAt: t10,
        );
        await deviceA.expenseRepo.save(editA);

        // 5. Device B makes a newer edit to the SAME row at T=20s
        final t20 = t0.add(const Duration(seconds: 20));
        deviceB.clock.current = t20;
        final editB = expenseOnB.copyWith(
          name: 'Device B Lunch - Final',
          amount: const Money.fromMinorUnits(35000), // 350.00
          clientUpdatedAt: t20,
        );
        await deviceB.expenseRepo.save(editB);

        // 6. Network reconnects
        sharedRemote.isOnline = true;

        // 7. Device A reconnects and syncs first
        final drainA2 = await deviceA.syncService.drain();
        expect(drainA2.successCount, 1);

        // 8. Device B reconnects and syncs second (newer timestamp)
        final drainB2 = await deviceB.syncService.drain();
        expect(drainB2.successCount, 1);

        // 9. Both devices pull to synchronize
        await deviceA.pullService.pull();
        await deviceB.pullService.pull();

        // 10. Verification: Device B's newer edit (T=20) wins everywhere!
        final finalRowOnA = await deviceA.expenseRepo.getById(
          'exp-shared-1',
          userId: userId,
        );
        final finalRowOnB = await deviceB.expenseRepo.getById(
          'exp-shared-1',
          userId: userId,
        );

        expect(finalRowOnA, isNotNull);
        expect(finalRowOnB, isNotNull);

        expect(finalRowOnA!.name, 'Device B Lunch - Final');
        expect(finalRowOnA.amount.minorUnits, 35000);

        expect(finalRowOnB!.name, 'Device B Lunch - Final');
        expect(finalRowOnB.amount.minorUnits, 35000);

        // Verify no duplicates
        final allOnA = await (deviceA.db.select(deviceA.db.expenses)).get();
        final allOnB = await (deviceB.db.select(deviceB.db.expenses)).get();
        expect(allOnA.length, 1);
        expect(allOnB.length, 1);
      });
    },
  );

  group('TASK-027: Two-Device Sync - M6: Tombstone Propagation', () {
    test('soft delete on Device A propagates as tombstone to Device B and disappears from active UI', () async {
      // 1. Device A creates a contact at T=0
      final contact = Contact(
        id: 'cnt-shared-1',
        userId: userId,
        name: 'Marta Hailu',
        phone: '+251911445566',
        createdAt: t0,
        clientUpdatedAt: t0,
      );
      await deviceA.contactRepo.save(contact);

      // Device A pushes to remote
      await deviceA.syncService.drain();

      // 2. Device B pulls contact
      await deviceB.pullService.pull();
      final contactOnB = await deviceB.contactRepo.getById(
        'cnt-shared-1',
        userId: userId,
      );
      expect(contactOnB, isNotNull);
      expect(contactOnB!.name, 'Marta Hailu');

      // 3. Device A soft deletes the contact at T=15s
      final t15 = t0.add(const Duration(seconds: 15));
      deviceA.clock.current = t15;
      await deviceA.contactRepo.softDelete('cnt-shared-1', userId: userId);

      // Contact is already gone from Device A active queries
      expect(
        await deviceA.contactRepo.getById('cnt-shared-1', userId: userId),
        isNull,
      );

      // 4. Device A syncs deletion to remote
      final drainDelete = await deviceA.syncService.drain();
      expect(drainDelete.successCount, 1);

      // Verify remote has deleted_at tombstone
      final remoteRow = sharedRemote.getRow('contacts', 'cnt-shared-1');
      expect(remoteRow, isNotNull);
      expect(remoteRow!['deleted_at'], isNotNull);

      // 5. Device B pulls remote changes
      final pullResult = await deviceB.pullService.pull();
      expect(pullResult.tombstoneCount, 1);

      // 6. Verification: Contact disappeared from Device B active queries!
      final activeOnB = await deviceB.contactRepo.getById(
        'cnt-shared-1',
        userId: userId,
      );
      expect(activeOnB, isNull);

      final allActiveOnB = await deviceB.contactRepo.getAll(userId: userId);
      expect(allActiveOnB.isEmpty, isTrue);

      // Raw SQLite row on Device B preserves tombstone for sync consistency
      final rawB = await (deviceB.db.select(
        deviceB.db.contacts,
      )..where((c) => c.id.equals('cnt-shared-1'))).getSingle();
      expect(rawB.deletedAt, isNotNull);
    });
  });
}
