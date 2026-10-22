import 'package:drift/drift.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' as db;
import 'package:haqly_mobile/domain/balance_calculator.dart';
import 'package:haqly_mobile/domain/models/category_total.dart';
import 'package:haqly_mobile/domain/models/expense.dart';
import 'package:haqly_mobile/domain/models/transaction_type.dart';
import 'package:haqly_mobile/domain/money.dart';

/// Abstract contract for managing user expenses and income entries.
/// Follows docs/ARCHITECTURE.md Section 4 and docs/RULES.md.
abstract class ExpenseRepository {
  /// Atomically persists or updates an expense/income row and enqueues an outbox pointer.
  Future<void> save(Expense expense);

  /// Atomically marks an entry as soft-deleted and enqueues an outbox pointer.
  Future<void> softDelete(String id, {String userId = 'LOCAL'});

  /// Retrieves a single active (non-deleted) expense by id.
  Future<Expense?> getById(String id, {String userId = 'LOCAL'});

  /// Watches all active entries, ordered by local date descending, then creation time descending.
  Stream<List<Expense>> watchAll({
    String userId = 'LOCAL',
    TransactionType? type,
  });

  /// Watches active entries for a specific device-local date (e.g. today).
  Stream<List<Expense>> watchByDate(
    String localDate, {
    String userId = 'LOCAL',
    TransactionType? type,
  });

  /// Watches active entries within an inclusive local date range [startLocalDate, endLocalDate].
  Stream<List<Expense>> watchByDateRange(
    String startLocalDate,
    String endLocalDate, {
    String userId = 'LOCAL',
    TransactionType? type,
  });

  /// Calculates the total money sum for a single local date.
  Future<Money> getTotalsForDate(
    String localDate, {
    String userId = 'LOCAL',
    TransactionType? type,
  });

  /// Calculates the total money sum for an inclusive local date range.
  Future<Money> getTotalsForDateRange(
    String startLocalDate,
    String endLocalDate, {
    String userId = 'LOCAL',
    TransactionType? type,
  });

  /// Calculates aggregated totals and item counts grouped by category.
  Future<List<CategoryTotal>> getByCategoryTotals({
    String? startLocalDate,
    String? endLocalDate,
    String userId = 'LOCAL',
    TransactionType type = TransactionType.expense,
  });

  /// Calculates income, expense, and net balance for an inclusive date range.
  Future<MonthBalance> getBalanceForDateRange(
    String startLocalDate,
    String endLocalDate, {
    String userId = 'LOCAL',
  });

  /// Calculates income, expense, and net balance for a specific year-month ('YYYY-MM').
  Future<MonthBalance> getMonthBalance(
    String yearMonth, {
    String userId = 'LOCAL',
  });
}

/// Drift SQLite implementation of [ExpenseRepository].
/// All writes atomically insert/update the local record and outbox pointer.
class DriftExpenseRepository implements ExpenseRepository {
  DriftExpenseRepository(this._db, {this.clock = const SystemClock()});

  final db.AppDatabase _db;
  final Clock clock;

  @override
  Future<void> save(Expense expense) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      // 1. Write row with local_date and client_updated_at
      await _db
          .into(_db.expenses)
          .insertOnConflictUpdate(
            db.ExpensesCompanion(
              id: Value(expense.id),
              userId: Value(expense.userId),
              name: Value(expense.name),
              amountMinor: Value(expense.amount.minorUnits),
              category: Value(expense.category),
              type: Value(expense.type.name),
              localDate: Value(expense.localDate),
              createdAt: Value(expense.createdAt.toUtc().toIso8601String()),
              clientUpdatedAt: Value(nowUtcIso),
              deletedAt: Value(expense.deletedAt?.toUtc().toIso8601String()),
            ),
          );

      // 2. Insert or coalesce outbox entry
      await _enqueueOutbox('expenses', expense.id, nowUtcIso);
    });
  }

  @override
  Future<void> softDelete(String id, {String userId = 'LOCAL'}) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      final updatedRows =
          await (_db.update(_db.expenses)..where(
                (e) =>
                    e.id.equals(id) &
                    e.userId.equals(userId) &
                    e.deletedAt.isNull(),
              ))
              .write(
                db.ExpensesCompanion(
                  deletedAt: Value(nowUtcIso),
                  clientUpdatedAt: Value(nowUtcIso),
                ),
              );

      if (updatedRows > 0) {
        await _enqueueOutbox('expenses', id, nowUtcIso);
      }
    });
  }

  @override
  Future<Expense?> getById(String id, {String userId = 'LOCAL'}) async {
    final row =
        await (_db.select(_db.expenses)..where(
              (e) =>
                  e.id.equals(id) &
                  e.userId.equals(userId) &
                  e.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    return row != null ? _mapToDomain(row) : null;
  }

  @override
  Stream<List<Expense>> watchAll({
    String userId = 'LOCAL',
    TransactionType? type,
  }) {
    final query = _db.select(_db.expenses)
      ..where(
        (e) =>
            e.userId.equals(userId) &
            e.deletedAt.isNull() &
            (type != null ? e.type.equals(type.name) : const Constant(true)),
      )
      ..orderBy([
        (e) => OrderingTerm.desc(e.localDate),
        (e) => OrderingTerm.desc(e.createdAt),
      ]);

    return query.watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Stream<List<Expense>> watchByDate(
    String localDate, {
    String userId = 'LOCAL',
    TransactionType? type,
  }) {
    final query = _db.select(_db.expenses)
      ..where(
        (e) =>
            e.userId.equals(userId) &
            e.localDate.equals(localDate) &
            e.deletedAt.isNull() &
            (type != null ? e.type.equals(type.name) : const Constant(true)),
      )
      ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]);

    return query.watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Stream<List<Expense>> watchByDateRange(
    String startLocalDate,
    String endLocalDate, {
    String userId = 'LOCAL',
    TransactionType? type,
  }) {
    final query = _db.select(_db.expenses)
      ..where(
        (e) =>
            e.userId.equals(userId) &
            e.localDate.isBiggerOrEqualValue(startLocalDate) &
            e.localDate.isSmallerOrEqualValue(endLocalDate) &
            e.deletedAt.isNull() &
            (type != null ? e.type.equals(type.name) : const Constant(true)),
      )
      ..orderBy([
        (e) => OrderingTerm.desc(e.localDate),
        (e) => OrderingTerm.desc(e.createdAt),
      ]);

    return query.watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Future<Money> getTotalsForDate(
    String localDate, {
    String userId = 'LOCAL',
    TransactionType? type,
  }) async {
    return getTotalsForDateRange(
      localDate,
      localDate,
      userId: userId,
      type: type,
    );
  }

  @override
  Future<Money> getTotalsForDateRange(
    String startLocalDate,
    String endLocalDate, {
    String userId = 'LOCAL',
    TransactionType? type,
  }) async {
    final sumAmount = _db.expenses.amountMinor.sum();
    final query = _db.selectOnly(_db.expenses)
      ..where(
        _db.expenses.userId.equals(userId) &
            _db.expenses.localDate.isBiggerOrEqualValue(startLocalDate) &
            _db.expenses.localDate.isSmallerOrEqualValue(endLocalDate) &
            _db.expenses.deletedAt.isNull() &
            (type != null
                ? _db.expenses.type.equals(type.name)
                : const Constant(true)),
      )
      ..addColumns([sumAmount]);

    final row = await query.getSingle();
    final totalMinor = row.read(sumAmount) ?? 0;
    return Money.fromMinorUnits(totalMinor);
  }

  @override
  Future<List<CategoryTotal>> getByCategoryTotals({
    String? startLocalDate,
    String? endLocalDate,
    String userId = 'LOCAL',
    TransactionType type = TransactionType.expense,
  }) async {
    final sumAmount = _db.expenses.amountMinor.sum();
    final countItems = _db.expenses.id.count();

    final query = _db.selectOnly(_db.expenses)
      ..where(
        _db.expenses.userId.equals(userId) &
            _db.expenses.type.equals(type.name) &
            _db.expenses.deletedAt.isNull() &
            (startLocalDate != null
                ? _db.expenses.localDate.isBiggerOrEqualValue(startLocalDate)
                : const Constant(true)) &
            (endLocalDate != null
                ? _db.expenses.localDate.isSmallerOrEqualValue(endLocalDate)
                : const Constant(true)),
      )
      ..groupBy([_db.expenses.category])
      ..orderBy([OrderingTerm.desc(sumAmount)])
      ..addColumns([_db.expenses.category, sumAmount, countItems]);

    final rows = await query.get();
    return rows.map((row) {
      final category = row.read(_db.expenses.category) ?? 'Other';
      final totalMinor = row.read(sumAmount) ?? 0;
      final count = row.read(countItems) ?? 0;
      return CategoryTotal(
        category: category,
        total: Money.fromMinorUnits(totalMinor),
        count: count,
      );
    }).toList();
  }

  @override
  Future<MonthBalance> getBalanceForDateRange(
    String startLocalDate,
    String endLocalDate, {
    String userId = 'LOCAL',
  }) async {
    final expense = await getTotalsForDateRange(
      startLocalDate,
      endLocalDate,
      userId: userId,
      type: TransactionType.expense,
    );
    final income = await getTotalsForDateRange(
      startLocalDate,
      endLocalDate,
      userId: userId,
      type: TransactionType.income,
    );
    return MonthBalance(income: income, expense: expense);
  }

  @override
  Future<MonthBalance> getMonthBalance(
    String yearMonth, {
    String userId = 'LOCAL',
  }) {
    final start = '$yearMonth-01';
    final end = '$yearMonth-31';
    return getBalanceForDateRange(start, end, userId: userId);
  }

  /// Internal helper to coalesce outbox entries per row.
  /// Follows docs/ARCHITECTURE.md Section 4:
  /// Multiple outbox entries for the same row coalesce to one upsert.
  Future<void> _enqueueOutbox(
    String tableName,
    String rowId,
    String nowUtcIso,
  ) async {
    final existingOutbox =
        await (_db.select(_db.outbox)..where(
              (o) => o.recordTable.equals(tableName) & o.rowId.equals(rowId),
            ))
            .getSingleOrNull();

    if (existingOutbox == null) {
      await _db
          .into(_db.outbox)
          .insert(
            db.OutboxCompanion.insert(
              recordTable: tableName,
              rowId: rowId,
              createdAt: nowUtcIso,
            ),
          );
    } else {
      await (_db.update(
        _db.outbox,
      )..where((o) => o.id.equals(existingOutbox.id))).write(
        db.OutboxCompanion(
          createdAt: Value(nowUtcIso),
          attempts: const Value(0),
          lastError: const Value(null),
        ),
      );
    }
  }

  Expense _mapToDomain(db.Expense row) {
    return Expense(
      id: row.id,
      userId: row.userId,
      name: row.name,
      amount: Money.fromMinorUnits(row.amountMinor),
      category: row.category,
      type: TransactionType.fromString(row.type),
      localDate: row.localDate,
      createdAt: DateTime.parse(row.createdAt),
      clientUpdatedAt: DateTime.parse(row.clientUpdatedAt),
      deletedAt: row.deletedAt != null ? DateTime.parse(row.deletedAt!) : null,
    );
  }
}
