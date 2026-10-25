import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' hide Budget;
import 'package:haqly_mobile/data/repositories/budget_repository.dart';
import 'package:haqly_mobile/domain/models/budget.dart';
import 'package:haqly_mobile/domain/money.dart';

void main() {
  late AppDatabase db;
  late DriftBudgetRepository repo;
  final fixedClock = FixedClock(DateTime.utc(2026, 10, 24, 12, 0, 0));

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftBudgetRepository(db, clock: fixedClock);
  });

  tearDown(() async {
    await db.close();
  });

  Budget createSampleBudget({
    String id = 'bgt-1',
    String userId = 'LOCAL',
    int? monthlyMinor = 1500000, // Br 15,000.00
    int? weeklyMinor = 350000, // Br 3,500.00
    DateTime? updatedAt,
  }) {
    final updated = updatedAt ?? DateTime.utc(2026, 10, 24, 10, 0, 0);
    return Budget(
      id: id,
      userId: userId,
      monthly: monthlyMinor != null ? Money.fromMinorUnits(monthlyMinor) : null,
      weekly: weeklyMinor != null ? Money.fromMinorUnits(weeklyMinor) : null,
      updatedAt: updated,
      clientUpdatedAt: updated,
    );
  }

  group('TASK-024: BudgetRepository - Save & Outbox Atomicity', () {
    test(
      'save inserts budget and enqueues outbox pointer atomically',
      () async {
        final budget = createSampleBudget();
        await repo.save(budget);

        final fetched = await repo.getBudget();
        expect(fetched, isNotNull);
        expect(fetched!.id, 'bgt-1');
        expect(fetched.userId, 'LOCAL');
        expect(fetched.monthly?.minorUnits, 1500000);
        expect(fetched.weekly?.minorUnits, 350000);

        // Verify outbox pointer
        final outboxEntries = await db.select(db.outbox).get();
        expect(outboxEntries.length, 1);
        expect(outboxEntries.first.recordTable, 'budgets');
        expect(outboxEntries.first.rowId, 'bgt-1');
        expect(outboxEntries.first.attempts, 0);
      },
    );

    test('save updates existing budget and coalesces outbox pointer', () async {
      final initial = createSampleBudget();
      await repo.save(initial);

      final updated = initial.copyWith(
        monthly: () => const Money.fromMinorUnits(2000000),
      );
      await repo.save(updated);

      final fetched = await repo.getBudget();
      expect(fetched!.monthly?.minorUnits, 2000000);

      // Verify outbox has coalesced to exactly 1 entry
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.recordTable, 'budgets');
      expect(outboxEntries.first.rowId, 'bgt-1');
    });

    test(
      'save handles same userId with different id without constraint violation',
      () async {
        final initial = createSampleBudget(id: 'bgt-initial');
        await repo.save(initial);

        // Save another budget object for same user with different id
        final revised = createSampleBudget(
          id: 'bgt-revised',
          monthlyMinor: 1800000,
        );
        await repo.save(revised);

        final fetched = await repo.getBudget();
        expect(fetched, isNotNull);
        expect(fetched!.monthly?.minorUnits, 1800000);
        expect(fetched.id, 'bgt-initial'); // preserves initial id

        final outboxEntries = await db.select(db.outbox).get();
        expect(outboxEntries.length, 1);
        expect(outboxEntries.first.recordTable, 'budgets');
        expect(outboxEntries.first.rowId, 'bgt-initial');
      },
    );
  });

  group('TASK-024: BudgetRepository - setBudget & clearBudget', () {
    test('setBudget creates initial budget when none exists', () async {
      final result = await repo.setBudget(
        monthly: const Money.fromMinorUnits(1200000),
        weekly: const Money.fromMinorUnits(300000),
      );

      expect(result.userId, 'LOCAL');
      expect(result.monthly?.minorUnits, 1200000);
      expect(result.weekly?.minorUnits, 300000);

      final fetched = await repo.getBudget();
      expect(fetched, isNotNull);
      expect(fetched!.monthly?.minorUnits, 1200000);
      expect(fetched.weekly?.minorUnits, 300000);
    });

    test('setBudget updates existing budget without changing id', () async {
      final first = await repo.setBudget(
        monthly: const Money.fromMinorUnits(1000000),
      );

      final second = await repo.setBudget(
        monthly: const Money.fromMinorUnits(1500000),
        weekly: const Money.fromMinorUnits(350000),
      );

      expect(second.id, first.id);
      expect(second.monthly?.minorUnits, 1500000);
      expect(second.weekly?.minorUnits, 350000);

      final allRows = await db.select(db.budgets).get();
      expect(allRows.length, 1);
    });

    test(
      'clearBudget resets targets to null and enqueues outbox pointer',
      () async {
        await repo.setBudget(
          monthly: const Money.fromMinorUnits(1000000),
          weekly: const Money.fromMinorUnits(250000),
        );

        await repo.clearBudget();

        final fetched = await repo.getBudget();
        expect(fetched, isNotNull);
        expect(fetched!.monthly, isNull);
        expect(fetched.weekly, isNull);
        expect(fetched.isEmpty, isTrue);

        final outboxEntries = await db.select(db.outbox).get();
        expect(outboxEntries.length, 1);
        expect(outboxEntries.first.recordTable, 'budgets');
      },
    );

    test('clearBudget on nonexistent budget is a safe no-op', () async {
      await repo.clearBudget();

      final fetched = await repo.getBudget();
      expect(fetched, isNull);

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.isEmpty, isTrue);
    });
  });

  group('TASK-024: BudgetRepository - Reactive Streams', () {
    test(
      'watchBudget emits null then updates as budget is created and cleared',
      () async {
        final streamEvents = <Budget?>[];
        final subscription = repo.watchBudget().listen(streamEvents.add);

        // Initial state
        await pumpEventQueue();
        expect(streamEvents.length, 1);
        expect(streamEvents.first, isNull);

        // Set budget
        await repo.setBudget(monthly: const Money.fromMinorUnits(500000));
        await pumpEventQueue();
        expect(streamEvents.length, 2);
        expect(streamEvents.last?.monthly?.minorUnits, 500000);

        // Clear budget
        await repo.clearBudget();
        await pumpEventQueue();
        expect(streamEvents.length, 3);
        expect(streamEvents.last?.isEmpty, isTrue);

        await subscription.cancel();
      },
    );
  });
}
