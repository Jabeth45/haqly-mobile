import 'package:drift/drift.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';
import 'package:haqly_mobile/domain/models/auth_state.dart';

/// Result summary of an adoption operation.
class AdoptionResult {
  const AdoptionResult({
    required this.totalAdopted,
    required this.adoptedExpenses,
    required this.adoptedChecks,
    required this.adoptedLedger,
    required this.adoptedBudgets,
    required this.adoptedContacts,
    required this.adoptedCategories,
  });

  const AdoptionResult.zero()
    : totalAdopted = 0,
      adoptedExpenses = 0,
      adoptedChecks = 0,
      adoptedLedger = 0,
      adoptedBudgets = 0,
      adoptedContacts = 0,
      adoptedCategories = 0;

  final int totalAdopted;
  final int adoptedExpenses;
  final int adoptedChecks;
  final int adoptedLedger;
  final int adoptedBudgets;
  final int adoptedContacts;
  final int adoptedCategories;

  bool get hasChanges => totalAdopted > 0;
}

/// Service that adopts offline guest data (`user_id = 'LOCAL'`) into a new
/// authenticated or anonymous user account.
/// Follows docs/ARCHITECTURE.md Section 6 and ADR-004.
class AdoptionService {
  AdoptionService(this._db, this._outbox, {this.clock = const SystemClock()});

  final AppDatabase _db;
  final OutboxQueue _outbox;
  final Clock clock;

  /// In a single database transaction, adopts all rows from [fromUserId]
  /// (defaults to [AuthState.localSentinel]) to [newUserId], updates
  /// `client_updated_at`, and atomically enqueues outbox pointers.
  ///
  /// This operation is strictly idempotent: calling it multiple times
  /// when no [fromUserId] rows exist returns zero changes without side-effects.
  Future<AdoptionResult> adopt({
    required String newUserId,
    String fromUserId = AuthState.localSentinel,
  }) async {
    if (newUserId == fromUserId) {
      return const AdoptionResult.zero();
    }

    final now = clock.now().toUtc();
    final nowIso = now.toIso8601String();

    return _db.transaction(() async {
      // 1. Expenses & Income
      final localExpenses = await (_db.select(
        _db.expenses,
      )..where((tbl) => tbl.userId.equals(fromUserId))).get();
      for (final exp in localExpenses) {
        await (_db.update(
          _db.expenses,
        )..where((tbl) => tbl.id.equals(exp.id))).write(
          ExpensesCompanion(
            userId: Value(newUserId),
            clientUpdatedAt: Value(nowIso),
          ),
        );
        await _outbox.enqueue('expenses', exp.id, now: now);
      }

      // 2. Check Items
      final localChecks = await (_db.select(
        _db.checkItems,
      )..where((tbl) => tbl.userId.equals(fromUserId))).get();
      for (final chk in localChecks) {
        await (_db.update(
          _db.checkItems,
        )..where((tbl) => tbl.id.equals(chk.id))).write(
          CheckItemsCompanion(
            userId: Value(newUserId),
            clientUpdatedAt: Value(nowIso),
          ),
        );
        await _outbox.enqueue('check_items', chk.id, now: now);
      }

      // 3. Ledger Entries
      final localLedgers = await (_db.select(
        _db.ledgerEntries,
      )..where((tbl) => tbl.userId.equals(fromUserId))).get();
      for (final led in localLedgers) {
        await (_db.update(
          _db.ledgerEntries,
        )..where((tbl) => tbl.id.equals(led.id))).write(
          LedgerEntriesCompanion(
            userId: Value(newUserId),
            clientUpdatedAt: Value(nowIso),
          ),
        );
        await _outbox.enqueue('ledger_entries', led.id, now: now);
      }

      // 4. Budgets
      final localBudgets = await (_db.select(
        _db.budgets,
      )..where((tbl) => tbl.userId.equals(fromUserId))).get();
      for (final b in localBudgets) {
        await (_db.update(
          _db.budgets,
        )..where((tbl) => tbl.id.equals(b.id))).write(
          BudgetsCompanion(
            userId: Value(newUserId),
            clientUpdatedAt: Value(nowIso),
          ),
        );
        await _outbox.enqueue('budgets', b.id, now: now);
      }

      // 5. Contacts
      final localContacts = await (_db.select(
        _db.contacts,
      )..where((tbl) => tbl.userId.equals(fromUserId))).get();
      for (final c in localContacts) {
        await (_db.update(
          _db.contacts,
        )..where((tbl) => tbl.id.equals(c.id))).write(
          ContactsCompanion(
            userId: Value(newUserId),
            clientUpdatedAt: Value(nowIso),
          ),
        );
        await _outbox.enqueue('contacts', c.id, now: now);
      }

      // 6. User Categories
      final localCategories = await (_db.select(
        _db.userCategories,
      )..where((tbl) => tbl.userId.equals(fromUserId))).get();
      for (final cat in localCategories) {
        await (_db.update(
          _db.userCategories,
        )..where((tbl) => tbl.id.equals(cat.id))).write(
          UserCategoriesCompanion(
            userId: Value(newUserId),
            clientUpdatedAt: Value(nowIso),
          ),
        );
        await _outbox.enqueue('user_categories', cat.id, now: now);
      }

      final total =
          localExpenses.length +
          localChecks.length +
          localLedgers.length +
          localBudgets.length +
          localContacts.length +
          localCategories.length;

      return AdoptionResult(
        totalAdopted: total,
        adoptedExpenses: localExpenses.length,
        adoptedChecks: localChecks.length,
        adoptedLedger: localLedgers.length,
        adoptedBudgets: localBudgets.length,
        adoptedContacts: localContacts.length,
        adoptedCategories: localCategories.length,
      );
    });
  }
}
