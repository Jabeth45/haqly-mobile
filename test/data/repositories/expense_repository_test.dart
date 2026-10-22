import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' hide Expense;
import 'package:haqly_mobile/data/repositories/expense_repository.dart';
import 'package:haqly_mobile/domain/models/expense.dart';
import 'package:haqly_mobile/domain/models/transaction_type.dart';
import 'package:haqly_mobile/domain/money.dart';

void main() {
  late AppDatabase db;
  late DriftExpenseRepository repo;
  final fixedClock = FixedClock(DateTime.utc(2026, 10, 23, 12, 0, 0));

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftExpenseRepository(db, clock: fixedClock);
  });

  tearDown(() async {
    await db.close();
  });

  Expense createSampleExpense({
    String id = 'exp-1',
    String name = 'Injera Lunch',
    int amountMinor = 15000, // 150.00 ETB
    String category = 'Food',
    TransactionType type = TransactionType.expense,
    String localDate = '2026-10-23',
    DateTime? deletedAt,
  }) {
    return Expense(
      id: id,
      name: name,
      amount: Money.fromMinorUnits(amountMinor),
      category: category,
      type: type,
      localDate: localDate,
      createdAt: DateTime.utc(2026, 10, 23, 10, 0, 0),
      clientUpdatedAt: DateTime.utc(2026, 10, 23, 10, 0, 0),
      deletedAt: deletedAt,
    );
  }

  group('TASK-021: ExpenseRepository - CRUD & Outbox Atomicity', () {
    test('save inserts row and atomically creates outbox pointer', () async {
      final expense = createSampleExpense();
      await repo.save(expense);

      final fetched = await repo.getById('exp-1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'exp-1');
      expect(fetched.name, 'Injera Lunch');
      expect(fetched.amount.minorUnits, 15000);
      expect(fetched.category, 'Food');
      expect(fetched.type, TransactionType.expense);
      expect(fetched.localDate, '2026-10-23');

      // Verify outbox entry was created atomically
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.recordTable, 'expenses');
      expect(outboxEntries.first.rowId, 'exp-1');
      expect(outboxEntries.first.attempts, 0);
    });

    test('multiple saves coalesce to a single outbox entry', () async {
      final expense1 = createSampleExpense();
      await repo.save(expense1);

      // Update the expense
      final expense2 = expense1.copyWith(name: 'Buffet Lunch');
      await repo.save(expense2);

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1, reason: 'Outbox entries must coalesce');
      expect(outboxEntries.first.rowId, 'exp-1');

      final fetched = await repo.getById('exp-1');
      expect(fetched!.name, 'Buffet Lunch');
    });

    test('softDelete sets deleted_at and enqueues outbox atomically', () async {
      final expense = createSampleExpense();
      await repo.save(expense);

      await repo.softDelete('exp-1');

      // Row still exists in SQLite with deleted_at set
      final rawRow = await (db.select(
        db.expenses,
      )..where((e) => e.id.equals('exp-1'))).getSingle();
      expect(rawRow.deletedAt, isNotNull);

      // But getById filters out soft-deleted row
      final fetched = await repo.getById('exp-1');
      expect(fetched, isNull);

      // Outbox still holds the single coalesced pointer for sync
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.rowId, 'exp-1');
    });

    test(
      'softDelete on non-existent id does not fail or enqueue outbox',
      () async {
        await repo.softDelete('non-existent-id');
        final outboxEntries = await db.select(db.outbox).get();
        expect(outboxEntries, isEmpty);
      },
    );
  });

  group('TASK-021: ExpenseRepository - Totals & Date Range Grouping', () {
    setUp(() async {
      // Seed 3 expenses and 1 income across different dates
      await repo.save(
        createSampleExpense(
          id: 'e1',
          name: 'Coffee',
          amountMinor: 3000, // 30.00
          category: 'Food',
          localDate: '2026-10-21',
        ),
      );
      await repo.save(
        createSampleExpense(
          id: 'e2',
          name: 'Taxi',
          amountMinor: 7000, // 70.00
          category: 'Transport',
          localDate: '2026-10-22',
        ),
      );
      await repo.save(
        createSampleExpense(
          id: 'e3',
          name: 'Groceries',
          amountMinor: 50000, // 500.00
          category: 'Food',
          localDate: '2026-10-23',
        ),
      );
      await repo.save(
        createSampleExpense(
          id: 'i1',
          name: 'Salary / Freelance',
          amountMinor: 200000, // 2000.00
          category: 'Income',
          type: TransactionType.income,
          localDate: '2026-10-22',
        ),
      );
    });

    test('getTotalsForDate calculates accurate daily sum', () async {
      final total23 = await repo.getTotalsForDate('2026-10-23');
      expect(total23.minorUnits, 50000);

      final total22Expenses = await repo.getTotalsForDate(
        '2026-10-22',
        type: TransactionType.expense,
      );
      expect(total22Expenses.minorUnits, 7000);

      final total22Income = await repo.getTotalsForDate(
        '2026-10-22',
        type: TransactionType.income,
      );
      expect(total22Income.minorUnits, 200000);
    });

    test(
      'getTotalsForDateRange calculates weekly and monthly totals',
      () async {
        // Range covering 2026-10-21 to 2026-10-23 for expenses
        final weeklyExpenses = await repo.getTotalsForDateRange(
          '2026-10-21',
          '2026-10-23',
          type: TransactionType.expense,
        );
        expect(weeklyExpenses.minorUnits, 3000 + 7000 + 50000); // 60,000

        final weeklyIncome = await repo.getTotalsForDateRange(
          '2026-10-21',
          '2026-10-23',
          type: TransactionType.income,
        );
        expect(weeklyIncome.minorUnits, 200000);
      },
    );

    test('soft-deleted expenses are excluded from totals', () async {
      await repo.softDelete('e1'); // Delete Coffee (3000)

      final rangeTotal = await repo.getTotalsForDateRange(
        '2026-10-21',
        '2026-10-23',
        type: TransactionType.expense,
      );
      expect(rangeTotal.minorUnits, 7000 + 50000); // e1 excluded
    });
  });

  group('TASK-021: ExpenseRepository - By-Category Breakdown', () {
    test(
      'getByCategoryTotals aggregates and sorts categories by highest spend',
      () async {
        await repo.save(
          createSampleExpense(
            id: 'c1',
            name: 'Injera',
            amountMinor: 20000,
            category: 'Food',
            localDate: '2026-10-20',
          ),
        );
        await repo.save(
          createSampleExpense(
            id: 'c2',
            name: 'Coffee',
            amountMinor: 5000,
            category: 'Food',
            localDate: '2026-10-21',
          ),
        );
        await repo.save(
          createSampleExpense(
            id: 'c3',
            name: 'Ride share',
            amountMinor: 15000,
            category: 'Transport',
            localDate: '2026-10-22',
          ),
        );

        final breakdown = await repo.getByCategoryTotals();
        expect(breakdown.length, 2);

        // Top category is Food: 20000 + 5000 = 25000 (2 items)
        expect(breakdown[0].category, 'Food');
        expect(breakdown[0].total.minorUnits, 25000);
        expect(breakdown[0].count, 2);

        // Second is Transport: 15000 (1 item)
        expect(breakdown[1].category, 'Transport');
        expect(breakdown[1].total.minorUnits, 15000);
        expect(breakdown[1].count, 1);
      },
    );
  });

  group('TASK-021: ExpenseRepository - Income, Expense & Net Balance', () {
    test(
      'getMonthBalance calculates balance, left amounts and negative balance',
      () async {
        // Income: 100,000 (Br 1,000.00)
        await repo.save(
          createSampleExpense(
            id: 'inc-1',
            name: 'Monthly Stipend',
            amountMinor: 100000,
            type: TransactionType.income,
            category: 'Salary',
            localDate: '2026-10-05',
          ),
        );

        // Expense: 40,000 (Br 400.00)
        await repo.save(
          createSampleExpense(
            id: 'exp-1',
            name: 'Shopping',
            amountMinor: 40000,
            type: TransactionType.expense,
            category: 'Shopping',
            localDate: '2026-10-10',
          ),
        );

        final balance = await repo.getMonthBalance('2026-10');
        expect(balance.income.minorUnits, 100000);
        expect(balance.expense.minorUnits, 40000);
        expect(balance.leftMinorUnits, 60000);
        expect(balance.isNegative, false);
        expect(balance.formatLeft(), 'Br 600.00');

        // Now add more expenses exceeding income
        await repo.save(
          createSampleExpense(
            id: 'exp-2',
            name: 'Laptop Repair',
            amountMinor: 80000,
            type: TransactionType.expense,
            category: 'Bills',
            localDate: '2026-10-15',
          ),
        );

        final deficitBalance = await repo.getMonthBalance('2026-10');
        expect(deficitBalance.expense.minorUnits, 120000); // 40,000 + 80,000
        expect(deficitBalance.leftMinorUnits, -20000);
        expect(deficitBalance.isNegative, true);
        expect(deficitBalance.formatLeft(), '-Br 200.00');
      },
    );
  });

  group('TASK-021: ExpenseRepository - Drift Reactive Streams', () {
    test(
      'watchByDate emits new list when item is added or soft-deleted',
      () async {
        final expectation = expectLater(
          repo.watchByDate('2026-10-23'),
          emitsInOrder([
            isEmpty, // Initial empty state
            hasLength(1), // After save
            isEmpty, // After soft delete
          ]),
        );

        // Wait for initial query to complete and emit initial empty state
        await pumpEventQueue();

        // Trigger 1: Save
        await repo.save(
          createSampleExpense(id: 'stream-1', localDate: '2026-10-23'),
        );
        await pumpEventQueue();

        // Trigger 2: Soft delete
        await repo.softDelete('stream-1');
        await expectation;
      },
    );
  });
}
