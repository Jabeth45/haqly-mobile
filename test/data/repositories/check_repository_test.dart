import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' hide CheckItem;
import 'package:haqly_mobile/data/repositories/check_repository.dart';
import 'package:haqly_mobile/domain/check_calculator.dart';
import 'package:haqly_mobile/domain/models/check_item.dart';
import 'package:haqly_mobile/domain/money.dart';

void main() {
  late AppDatabase db;
  late DriftCheckRepository repo;
  final fixedClock = FixedClock(DateTime.utc(2026, 10, 23, 12, 0, 0));

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftCheckRepository(db, clock: fixedClock);
  });

  tearDown(() async {
    await db.close();
  });

  CheckItem createSampleCheckItem({
    String id = 'chk-1',
    String name = 'Leather Jacket',
    int priceMinor = 350000,
    double uses = 100,
    int? costPerUseMinor = 3500,
    Verdict verdict = Verdict.worth,
    int regretLevel = 1,
    String localDate = '2026-10-23',
    DateTime? deletedAt,
  }) {
    return CheckItem(
      id: id,
      name: name,
      price: Money.fromMinorUnits(priceMinor),
      uses: uses,
      costPerUseMinor: costPerUseMinor,
      verdict: verdict,
      regretLevel: regretLevel,
      localDate: localDate,
      createdAt: DateTime.utc(2026, 10, 23, 10, 0, 0),
      clientUpdatedAt: DateTime.utc(2026, 10, 23, 10, 0, 0),
      deletedAt: deletedAt,
    );
  }

  group('TASK-022: CheckRepository - CRUD & Outbox Atomicity', () {
    test('save inserts item and creates outbox pointer atomically', () async {
      final item = createSampleCheckItem();
      await repo.save(item);

      final fetched = await repo.getById('chk-1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'chk-1');
      expect(fetched.name, 'Leather Jacket');
      expect(fetched.price.minorUnits, 350000);
      expect(fetched.uses, 100);
      expect(fetched.costPerUseMinor, 3500);
      expect(fetched.verdict, Verdict.worth);
      expect(fetched.regretLevel, 1);
      expect(fetched.localDate, '2026-10-23');

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.recordTable, 'check_items');
      expect(outboxEntries.first.rowId, 'chk-1');
      expect(outboxEntries.first.attempts, 0);
    });

    test('multiple saves coalesce to one outbox pointer', () async {
      final item1 = createSampleCheckItem();
      await repo.save(item1);

      final item2 = item1.copyWith(name: 'Winter Leather Jacket');
      await repo.save(item2);

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.rowId, 'chk-1');

      final fetched = await repo.getById('chk-1');
      expect(fetched!.name, 'Winter Leather Jacket');
    });

    test('softDelete sets deleted_at and enqueues outbox pointer', () async {
      final item = createSampleCheckItem();
      await repo.save(item);

      await repo.softDelete('chk-1');

      final fetched = await repo.getById('chk-1');
      expect(fetched, isNull);

      final raw = await (db.select(
        db.checkItems,
      )..where((c) => c.id.equals('chk-1'))).getSingle();
      expect(raw.deletedAt, isNotNull);

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.rowId, 'chk-1');
    });

    test('softDelete on non-existent id is no-op', () async {
      await repo.softDelete('unknown-id');
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries, isEmpty);
    });
  });

  group('TASK-022: CheckRepository - Verdicts and Queries', () {
    setUp(() async {
      await repo.save(
        createSampleCheckItem(
          id: 'c1',
          name: 'Shoes',
          verdict: Verdict.worth,
          localDate: '2026-10-20',
        ),
      );
      await repo.save(
        createSampleCheckItem(
          id: 'c2',
          name: 'Smart Watch',
          verdict: Verdict.maybe,
          localDate: '2026-10-21',
        ),
      );
      await repo.save(
        createSampleCheckItem(
          id: 'c3',
          name: 'Expensive Pen',
          verdict: Verdict.not,
          localDate: '2026-10-22',
        ),
      );
    });

    test(
      'getVerdicts extracts verdicts list excluding soft-deleted items',
      () async {
        final verdicts = await repo.getVerdicts();
        expect(verdicts.length, 3);
        expect(
          verdicts,
          containsAllInOrder([Verdict.not, Verdict.maybe, Verdict.worth]),
        );

        await repo.softDelete('c3');
        final afterDelete = await repo.getVerdicts();
        expect(afterDelete.length, 2);
        expect(afterDelete, containsAllInOrder([Verdict.maybe, Verdict.worth]));
      },
    );

    test('getVerdicts filters by localDate range', () async {
      final filtered = await repo.getVerdicts(
        startLocalDate: '2026-10-20',
        endLocalDate: '2026-10-21',
      );
      expect(filtered.length, 2);
      expect(filtered, containsAllInOrder([Verdict.maybe, Verdict.worth]));
    });

    test('getRecentVerdicts respects limit parameter', () async {
      final recent = await repo.getRecentVerdicts(limit: 2);
      expect(recent.length, 2);
      expect(recent[0], Verdict.not);
      expect(recent[1], Verdict.maybe);
    });
  });

  group('TASK-022: CheckRepository - Drift Reactive Streams', () {
    test('watchByDate emits list updates on write and soft delete', () async {
      final expectation = expectLater(
        repo.watchByDate('2026-10-23'),
        emitsInOrder([isEmpty, hasLength(1), isEmpty]),
      );

      await pumpEventQueue();
      await repo.save(
        createSampleCheckItem(id: 'stream-chk', localDate: '2026-10-23'),
      );
      await pumpEventQueue();
      await repo.softDelete('stream-chk');
      await expectation;
    });
  });
}
