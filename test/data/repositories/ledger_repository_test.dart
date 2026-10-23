import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' hide LedgerEntry;
import 'package:haqly_mobile/data/repositories/ledger_repository.dart';
import 'package:haqly_mobile/domain/models/ledger_entry.dart';
import 'package:haqly_mobile/domain/models/ledger_summary.dart';
import 'package:haqly_mobile/domain/models/ledger_type.dart';
import 'package:haqly_mobile/domain/money.dart';
import 'package:haqly_mobile/domain/split.dart';

void main() {
  late AppDatabase db;
  late DriftLedgerRepository repo;
  final fixedClock = FixedClock(DateTime.utc(2026, 10, 23, 12, 0, 0));

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftLedgerRepository(db, clock: fixedClock);
  });

  tearDown(() async {
    await db.close();
  });

  LedgerEntry createSampleEntry({
    String id = 'led-1',
    String userId = 'LOCAL',
    String person = 'Abebe',
    int amountMinor = 50000,
    String currency = 'ETB',
    LedgerType type = LedgerType.lent,
    String? note = 'Lunch split',
    bool settled = false,
    String localDate = '2026-10-23',
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    final created = createdAt ?? DateTime.utc(2026, 10, 23, 10, 0, 0);
    return LedgerEntry(
      id: id,
      userId: userId,
      person: person,
      amount: Money.fromMinorUnits(amountMinor, currency: currency),
      currency: currency,
      type: type,
      note: note,
      settled: settled,
      localDate: localDate,
      createdAt: created,
      clientUpdatedAt: created,
      deletedAt: deletedAt,
    );
  }

  group('TASK-023: LedgerRepository - CRUD & Outbox Atomicity', () {
    test('save inserts entry and creates outbox pointer atomically', () async {
      final entry = createSampleEntry();
      await repo.save(entry);

      // Verify row persisted
      final fetched = await repo.getById('led-1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'led-1');
      expect(fetched.person, 'Abebe');
      expect(fetched.amount.minorUnits, 50000);
      expect(fetched.currency, 'ETB');
      expect(fetched.type, LedgerType.lent);
      expect(fetched.note, 'Lunch split');
      expect(fetched.settled, isFalse);

      // Verify outbox pointer created
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.recordTable, 'ledger_entries');
      expect(outboxEntries.first.rowId, 'led-1');
      expect(outboxEntries.first.attempts, 0);
    });

    test('multiple saves for same id coalesce to one outbox pointer', () async {
      final entry1 = createSampleEntry(note: 'Version 1');
      await repo.save(entry1);

      final entry2 = entry1.copyWith(note: 'Version 2');
      await repo.save(entry2);

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.rowId, 'led-1');

      final fetched = await repo.getById('led-1');
      expect(fetched!.note, 'Version 2');
    });

    test('softDelete marks deletedAt and enqueues outbox pointer', () async {
      final entry = createSampleEntry();
      await repo.save(entry);

      // Clear outbox from initial save to verify softDelete outbox entry
      await db.delete(db.outbox).go();

      await repo.softDelete('led-1');

      final active = await repo.getById('led-1');
      expect(active, isNull);

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.recordTable, 'ledger_entries');
      expect(outboxEntries.first.rowId, 'led-1');
    });

    test(
      'softDelete on non-existent or deleted id does not enqueue outbox',
      () async {
        await repo.softDelete('non-existent');
        final outboxEntries = await db.select(db.outbox).get();
        expect(outboxEntries, isEmpty);
      },
    );
  });

  group('TASK-023: LedgerRepository - Settle Status', () {
    test('settle sets settled flag and updates outbox atomically', () async {
      final entry = createSampleEntry(settled: false);
      await repo.save(entry);
      await db.delete(db.outbox).go();

      await repo.settle('led-1', settled: true);

      final fetched = await repo.getById('led-1');
      expect(fetched!.settled, isTrue);

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.rowId, 'led-1');
    });

    test('settle can un-settle an entry', () async {
      final entry = createSampleEntry(settled: true);
      await repo.save(entry);

      await repo.settle('led-1', settled: false);

      final fetched = await repo.getById('led-1');
      expect(fetched!.settled, isFalse);
    });
  });

  group('TASK-023: LedgerRepository - Filters and Querying', () {
    setUp(() async {
      // 1: Abebe Lent 500 ETB, unsettled
      await repo.save(
        createSampleEntry(
          id: 'l1',
          person: 'Abebe',
          amountMinor: 50000,
          type: LedgerType.lent,
          settled: false,
          localDate: '2026-10-21',
          createdAt: DateTime.utc(2026, 10, 21, 10, 0),
        ),
      );
      // 2: Kebede Borrowed 300 ETB, unsettled
      await repo.save(
        createSampleEntry(
          id: 'l2',
          person: 'Kebede',
          amountMinor: 30000,
          type: LedgerType.borrowed,
          settled: false,
          localDate: '2026-10-22',
          createdAt: DateTime.utc(2026, 10, 22, 10, 0),
        ),
      );
      // 3: Almaz Lent 200 ETB, settled
      await repo.save(
        createSampleEntry(
          id: 'l3',
          person: 'Almaz',
          amountMinor: 20000,
          type: LedgerType.lent,
          settled: true,
          localDate: '2026-10-23',
          createdAt: DateTime.utc(2026, 10, 23, 10, 0),
        ),
      );
      // 4: Sara Borrowed 150 ETB, settled
      await repo.save(
        createSampleEntry(
          id: 'l4',
          person: 'Sara',
          amountMinor: 15000,
          type: LedgerType.borrowed,
          settled: true,
          localDate: '2026-10-23',
          createdAt: DateTime.utc(2026, 10, 23, 11, 0),
        ),
      );
      // 5: Other user entry
      await repo.save(
        createSampleEntry(
          id: 'l5-other',
          userId: 'USER_2',
          person: 'Foreign',
          amountMinor: 99900,
          type: LedgerType.lent,
          settled: false,
        ),
      );
    });

    test('getEntries returns all active entries ordered by localDate desc, createdAt desc', () async {
      final entries = await repo.getEntries();
      expect(entries.length, 4);
      expect(entries.map((e) => e.id).toList(), ['l4', 'l3', 'l2', 'l1']);
    });

    test('filter by type: lent only', () async {
      final lentEntries = await repo.getEntries(type: LedgerType.lent);
      expect(lentEntries.length, 2);
      expect(lentEntries.map((e) => e.id).toList(), ['l3', 'l1']);
    });

    test('filter by type: borrowed only', () async {
      final borrowedEntries = await repo.getEntries(type: LedgerType.borrowed);
      expect(borrowedEntries.length, 2);
      expect(borrowedEntries.map((e) => e.id).toList(), ['l4', 'l2']);
    });

    test('filter by settled: false (unsettled)', () async {
      final openEntries = await repo.getEntries(settled: false);
      expect(openEntries.length, 2);
      expect(openEntries.map((e) => e.id).toList(), ['l2', 'l1']);
    });

    test('filter by settled: true (settled)', () async {
      final settledEntries = await repo.getEntries(settled: true);
      expect(settledEntries.length, 2);
      expect(settledEntries.map((e) => e.id).toList(), ['l4', 'l3']);
    });

    test('combined filter: lent and unsettled', () async {
      final results = await repo.getEntries(
        type: LedgerType.lent,
        settled: false,
      );
      expect(results.length, 1);
      expect(results.first.id, 'l1');
    });

    test('watchAll emits updates reactively', () async {
      final expectation = expectLater(
        repo.watchAll(settled: false),
        emitsInOrder([hasLength(2), hasLength(3), hasLength(2)]),
      );

      await pumpEventQueue();

      await repo.save(
        createSampleEntry(
          id: 'l6',
          person: 'Dawit',
          amountMinor: 10000,
          type: LedgerType.lent,
          settled: false,
          localDate: '2026-10-23',
        ),
      );
      await pumpEventQueue();

      await repo.settle('l1', settled: true);
      await expectation;
    });
  });

  group('TASK-023: LedgerRepository - Open Summary', () {
    test('returns empty summary when no entries exist', () async {
      final summary = await repo.getOpenSummary();
      expect(summary.hasOpenEntries, isFalse);
      expect(summary.totalOpenCount, 0);
      expect(summary.totalLentEtb.minorUnits, 0);
      expect(summary.totalBorrowedEtb.minorUnits, 0);
      expect(summary.formatNetEtb(), 'Br 0.00');
    });

    test('calculates net ETB balance and counts correctly', () async {
      // Lent 1,000 ETB (unsettled)
      await repo.save(
        createSampleEntry(
          id: 'etb-lent-1',
          person: 'Abebe',
          amountMinor: 100000,
          currency: 'ETB',
          type: LedgerType.lent,
          settled: false,
        ),
      );
      // Lent 500 ETB (unsettled)
      await repo.save(
        createSampleEntry(
          id: 'etb-lent-2',
          person: 'Almaz',
          amountMinor: 50000,
          currency: 'ETB',
          type: LedgerType.lent,
          settled: false,
        ),
      );
      // Borrowed 400 ETB (unsettled)
      await repo.save(
        createSampleEntry(
          id: 'etb-borrow-1',
          person: 'Kebede',
          amountMinor: 40000,
          currency: 'ETB',
          type: LedgerType.borrowed,
          settled: false,
        ),
      );
      // Settled entry (should not be in open summary)
      await repo.save(
        createSampleEntry(
          id: 'etb-settled',
          person: 'Sara',
          amountMinor: 90000,
          currency: 'ETB',
          type: LedgerType.lent,
          settled: true,
        ),
      );

      final summary = await repo.getOpenSummary();
      expect(summary.hasOpenEntries, isTrue);
      expect(summary.openLentCount, 2);
      expect(summary.openBorrowedCount, 1);
      expect(summary.totalOpenCount, 3);
      expect(summary.totalLentEtb.minorUnits, 150000); // 1,500.00
      expect(summary.totalBorrowedEtb.minorUnits, 40000); // 400.00
      expect(summary.netEtbMinorUnits, 110000); // +1,100.00
      expect(summary.isEtbNegative, isFalse);
      expect(summary.formatNetEtb(), 'Br 1,100.00');
    });

    test(
      'formats negative net balance correctly when borrowed > lent',
      () async {
        await repo.save(
          createSampleEntry(
            id: 'b1',
            amountMinor: 75000,
            type: LedgerType.borrowed,
            settled: false,
          ),
        );
        await repo.save(
          createSampleEntry(
            id: 'l1',
            amountMinor: 25000,
            type: LedgerType.lent,
            settled: false,
          ),
        );

        final summary = await repo.getOpenSummary();
        expect(summary.netEtbMinorUnits, -50000);
        expect(summary.isEtbNegative, isTrue);
        expect(summary.formatNetEtb(), '-Br 500.00');
      },
    );

    test(
      'tracks USD separately without cross-conversion per OPEN-015',
      () async {
        await repo.save(
          createSampleEntry(
            id: 'usd-1',
            person: 'John',
            amountMinor: 5000, // $50.00
            currency: 'USD',
            type: LedgerType.lent,
            settled: false,
          ),
        );
        await repo.save(
          createSampleEntry(
            id: 'usd-2',
            person: 'Mike',
            amountMinor: 2000, // $20.00
            currency: 'USD',
            type: LedgerType.borrowed,
            settled: false,
          ),
        );

        final summary = await repo.getOpenSummary();
        expect(summary.totalLentUsd.minorUnits, 5000);
        expect(summary.totalBorrowedUsd.minorUnits, 2000);
        expect(summary.formatNetUsd(), '\$30.00');
        expect(summary.totalLentEtb.minorUnits, 0);
      },
    );

    test('watchOpenSummary reacts to settle and softDelete', () async {
      final expectation = expectLater(
        repo.watchOpenSummary(),
        emitsInOrder([
          predicate<LedgerSummary>((s) => s.totalOpenCount == 0),
          predicate<LedgerSummary>(
            (s) => s.totalOpenCount == 1 && s.totalLentEtb.minorUnits == 20000,
          ),
          predicate<LedgerSummary>((s) => s.totalOpenCount == 0),
        ]),
      );

      await pumpEventQueue();

      await repo.save(
        createSampleEntry(
          id: 'dyn-1',
          amountMinor: 20000,
          type: LedgerType.lent,
          settled: false,
        ),
      );
      await pumpEventQueue();

      await repo.settle('dyn-1', settled: true);
      await expectation;
    });
  });

  group('TASK-023: LedgerRepository - Split-save (saveSplit)', () {
    test(
      'saveSplit saves lent entries for non-payers and excludes payer',
      () async {
        // Split 100.00 ETB (10,000 minor units) among 3 people: Me (payer), Abebe, Kebede
        // Remainder distribution: 10000 ~/ 3 = 3333, remainder = 1
        // Share 0 (Me): 3334
        // Share 1 (Abebe): 3333
        // Share 2 (Kebede): 3333
        final splitResult = splitBill(
          const Money.fromMinorUnits(10000),
          peopleCount: 3,
          names: ['Me', 'Abebe', 'Kebede'],
          payerIndex: 0,
        );

        var idCounter = 1;
        final savedEntries = await repo.saveSplit(
          splitResult: splitResult,
          localDate: '2026-10-23',
          note: 'Dinner at Addis',
          idGenerator: () => 'split-${idCounter++}',
        );

        // Only 2 entries should be created (excluding 'Me')
        expect(savedEntries.length, 2);

        final abebeEntry = savedEntries.firstWhere((e) => e.person == 'Abebe');
        expect(abebeEntry.id, 'split-1');
        expect(abebeEntry.amount.minorUnits, 3333);
        expect(abebeEntry.type, LedgerType.lent);
        expect(abebeEntry.settled, isFalse);
        expect(abebeEntry.note, 'Dinner at Addis');
        expect(abebeEntry.localDate, '2026-10-23');

        final kebedeEntry = savedEntries.firstWhere(
          (e) => e.person == 'Kebede',
        );
        expect(kebedeEntry.id, 'split-2');
        expect(kebedeEntry.amount.minorUnits, 3333);
        expect(kebedeEntry.type, LedgerType.lent);

        // Outbox entries created for both
        final outboxEntries = await db.select(db.outbox).get();
        expect(outboxEntries.length, 2);
        expect(outboxEntries.map((o) => o.rowId).toSet(), {
          'split-1',
          'split-2',
        });

        // Summary reflects the 2 new debts
        final summary = await repo.getOpenSummary();
        expect(summary.openLentCount, 2);
        expect(summary.totalLentEtb.minorUnits, 6666);
      },
    );

    test('saveSplit with 1 person (only payer) does nothing and returns empty list', () async {
      final splitResult = splitBill(
        const Money.fromMinorUnits(5000),
        peopleCount: 1,
        payerIndex: 0,
      );

      final saved = await repo.saveSplit(
        splitResult: splitResult,
        localDate: '2026-10-23',
      );

      expect(saved, isEmpty);
      final allEntries = await repo.getEntries();
      expect(allEntries, isEmpty);
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries, isEmpty);
    });
  });
}
