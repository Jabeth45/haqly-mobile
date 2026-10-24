import 'package:drift/drift.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' as db;
import 'package:haqly_mobile/domain/models/budget.dart';
import 'package:haqly_mobile/domain/money.dart';
import 'package:haqly_mobile/domain/uuid_utils.dart';

/// Abstract contract for managing user budgets.
/// Follows docs/ARCHITECTURE.md Section 4 and docs/RULES.md.
abstract class BudgetRepository {
  /// Atomically persists or updates a budget and enqueues an outbox pointer.
  Future<void> save(Budget budget);

  /// Sets or updates the budget targets for [userId].
  /// If a budget record already exists, updates it; otherwise creates one.
  Future<Budget> setBudget({
    Money? monthly,
    Money? weekly,
    String userId = 'LOCAL',
    String? id,
  });

  /// Clears budget targets (sets monthly and weekly to null) and enqueues an outbox pointer.
  Future<void> clearBudget({String userId = 'LOCAL'});

  /// Retrieves the budget record for [userId], or null if none has been set.
  Future<Budget?> getBudget({String userId = 'LOCAL'});

  /// Watches the budget record for [userId] reactively.
  Stream<Budget?> watchBudget({String userId = 'LOCAL'});
}

/// Drift SQLite implementation of [BudgetRepository].
class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db, {this.clock = const SystemClock()});

  final db.AppDatabase _db;
  final Clock clock;

  @override
  Future<void> save(Budget budget) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.budgets,
      )..where((b) => b.userId.equals(budget.userId))).getSingleOrNull();

      final idToUse = existing?.id ?? budget.id;

      if (existing == null) {
        await _db
            .into(_db.budgets)
            .insert(
              db.BudgetsCompanion(
                id: Value(idToUse),
                userId: Value(budget.userId),
                monthlyMinor: Value(budget.monthly?.minorUnits),
                weeklyMinor: Value(budget.weekly?.minorUnits),
                updatedAt: Value(budget.updatedAt.toUtc().toIso8601String()),
                clientUpdatedAt: Value(nowUtcIso),
              ),
            );
      } else {
        await (_db.update(
          _db.budgets,
        )..where((b) => b.userId.equals(budget.userId))).write(
          db.BudgetsCompanion(
            monthlyMinor: Value(budget.monthly?.minorUnits),
            weeklyMinor: Value(budget.weekly?.minorUnits),
            updatedAt: Value(budget.updatedAt.toUtc().toIso8601String()),
            clientUpdatedAt: Value(nowUtcIso),
          ),
        );
      }

      await _enqueueOutbox('budgets', idToUse, nowUtcIso);
    });
  }

  @override
  Future<Budget> setBudget({
    Money? monthly,
    Money? weekly,
    String userId = 'LOCAL',
    String? id,
  }) async {
    final existing = await getBudget(userId: userId);
    final budgetId = id ?? existing?.id ?? generateUuidV4();
    final now = clock.now();

    final budget = Budget(
      id: budgetId,
      userId: userId,
      monthly: monthly,
      weekly: weekly,
      updatedAt: now,
      clientUpdatedAt: now,
    );

    await save(budget);
    return (await getBudget(userId: userId)) ?? budget;
  }

  @override
  Future<void> clearBudget({String userId = 'LOCAL'}) async {
    final existing = await getBudget(userId: userId);
    if (existing == null) return;

    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      final updated =
          await (_db.update(
            _db.budgets,
          )..where((b) => b.userId.equals(userId))).write(
            db.BudgetsCompanion(
              monthlyMinor: const Value(null),
              weeklyMinor: const Value(null),
              updatedAt: Value(nowUtcIso),
              clientUpdatedAt: Value(nowUtcIso),
            ),
          );

      if (updated > 0) {
        await _enqueueOutbox('budgets', existing.id, nowUtcIso);
      }
    });
  }

  @override
  Future<Budget?> getBudget({String userId = 'LOCAL'}) async {
    final row = await (_db.select(
      _db.budgets,
    )..where((b) => b.userId.equals(userId))).getSingleOrNull();

    if (row == null) return null;
    return _mapToDomain(row);
  }

  @override
  Stream<Budget?> watchBudget({String userId = 'LOCAL'}) {
    return (_db.select(_db.budgets)..where((b) => b.userId.equals(userId)))
        .watchSingleOrNull()
        .map((row) => row != null ? _mapToDomain(row) : null);
  }

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

  Budget _mapToDomain(db.Budget row) {
    return Budget(
      id: row.id,
      userId: row.userId,
      monthly: row.monthlyMinor != null
          ? Money.fromMinorUnits(row.monthlyMinor!)
          : null,
      weekly: row.weeklyMinor != null
          ? Money.fromMinorUnits(row.weeklyMinor!)
          : null,
      updatedAt: DateTime.parse(row.updatedAt),
      clientUpdatedAt: DateTime.parse(row.clientUpdatedAt),
    );
  }
}
