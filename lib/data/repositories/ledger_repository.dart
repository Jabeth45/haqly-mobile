import 'package:drift/drift.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' as db;
import 'package:haqly_mobile/domain/models/ledger_entry.dart';
import 'package:haqly_mobile/domain/models/ledger_summary.dart';
import 'package:haqly_mobile/domain/models/ledger_type.dart';
import 'package:haqly_mobile/domain/money.dart';
import 'package:haqly_mobile/domain/split.dart';
import 'package:haqly_mobile/domain/uuid_utils.dart';

/// Abstract contract for managing user debts and credits (Ledger).
/// Follows docs/ARCHITECTURE.md Section 4 and docs/RULES.md.
abstract class LedgerRepository {
  /// Atomically persists or updates a ledger entry and enqueues an outbox pointer.
  Future<void> save(LedgerEntry entry);

  /// Atomically marks an entry as soft-deleted and enqueues an outbox pointer.
  Future<void> softDelete(String id, {String userId = 'LOCAL'});

  /// Atomically updates the settled status of an entry and enqueues an outbox pointer.
  Future<void> settle(
    String id, {
    bool settled = true,
    String userId = 'LOCAL',
  });

  /// Retrieves a single active (non-deleted) ledger entry by id.
  Future<LedgerEntry?> getById(String id, {String userId = 'LOCAL'});

  /// Watches active ledger entries matching optional filters.
  /// Ordered by localDate descending, then createdAt descending.
  Stream<List<LedgerEntry>> watchAll({
    String userId = 'LOCAL',
    LedgerType? type,
    bool? settled,
  });

  /// Queries active ledger entries matching optional filters.
  Future<List<LedgerEntry>> getEntries({
    String userId = 'LOCAL',
    LedgerType? type,
    bool? settled,
  });

  /// Watches aggregated summary of open (unsettled) entries.
  Stream<LedgerSummary> watchOpenSummary({String userId = 'LOCAL'});

  /// Queries aggregated summary of open (unsettled) entries.
  Future<LedgerSummary> getOpenSummary({String userId = 'LOCAL'});

  /// Atomically saves a split bill result to the ledger:
  /// Creates one 'lent' entry for each non-payer person in [splitResult.lentEntries],
  /// in a single DB transaction with outbox pointers.
  /// Returns the saved [LedgerEntry] records.
  Future<List<LedgerEntry>> saveSplit({
    required SplitResult splitResult,
    required String localDate,
    String? note,
    String userId = 'LOCAL',
    String Function()? idGenerator,
  });
}

/// Drift SQLite implementation of [LedgerRepository].
class DriftLedgerRepository implements LedgerRepository {
  DriftLedgerRepository(this._db, {this.clock = const SystemClock()});

  final db.AppDatabase _db;
  final Clock clock;

  @override
  Future<void> save(LedgerEntry entry) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      await _db
          .into(_db.ledgerEntries)
          .insertOnConflictUpdate(
            db.LedgerEntriesCompanion(
              id: Value(entry.id),
              userId: Value(entry.userId),
              person: Value(entry.person),
              amountMinor: Value(entry.amount.minorUnits),
              currency: Value(entry.currency),
              type: Value(entry.type.wireValue),
              note: Value(entry.note),
              settled: Value(entry.settled),
              localDate: Value(entry.localDate),
              createdAt: Value(entry.createdAt.toUtc().toIso8601String()),
              clientUpdatedAt: Value(nowUtcIso),
              deletedAt: Value(entry.deletedAt?.toUtc().toIso8601String()),
            ),
          );

      await _enqueueOutbox('ledger_entries', entry.id, nowUtcIso);
    });
  }

  @override
  Future<void> softDelete(String id, {String userId = 'LOCAL'}) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      final updatedRows =
          await (_db.update(_db.ledgerEntries)..where(
                (l) =>
                    l.id.equals(id) &
                    l.userId.equals(userId) &
                    l.deletedAt.isNull(),
              ))
              .write(
                db.LedgerEntriesCompanion(
                  deletedAt: Value(nowUtcIso),
                  clientUpdatedAt: Value(nowUtcIso),
                ),
              );

      if (updatedRows > 0) {
        await _enqueueOutbox('ledger_entries', id, nowUtcIso);
      }
    });
  }

  @override
  Future<void> settle(
    String id, {
    bool settled = true,
    String userId = 'LOCAL',
  }) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      final updatedRows =
          await (_db.update(_db.ledgerEntries)..where(
                (l) =>
                    l.id.equals(id) &
                    l.userId.equals(userId) &
                    l.deletedAt.isNull(),
              ))
              .write(
                db.LedgerEntriesCompanion(
                  settled: Value(settled),
                  clientUpdatedAt: Value(nowUtcIso),
                ),
              );

      if (updatedRows > 0) {
        await _enqueueOutbox('ledger_entries', id, nowUtcIso);
      }
    });
  }

  @override
  Future<LedgerEntry?> getById(String id, {String userId = 'LOCAL'}) async {
    final row =
        await (_db.select(_db.ledgerEntries)..where(
              (l) =>
                  l.id.equals(id) &
                  l.userId.equals(userId) &
                  l.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    return row != null ? _mapToDomain(row) : null;
  }

  @override
  Stream<List<LedgerEntry>> watchAll({
    String userId = 'LOCAL',
    LedgerType? type,
    bool? settled,
  }) {
    final query = _buildEntriesQuery(
      userId: userId,
      type: type,
      settled: settled,
    );
    return query.watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Future<List<LedgerEntry>> getEntries({
    String userId = 'LOCAL',
    LedgerType? type,
    bool? settled,
  }) async {
    final query = _buildEntriesQuery(
      userId: userId,
      type: type,
      settled: settled,
    );
    final rows = await query.get();
    return rows.map(_mapToDomain).toList();
  }

  @override
  Stream<LedgerSummary> watchOpenSummary({String userId = 'LOCAL'}) {
    final query = _db.select(_db.ledgerEntries)
      ..where(
        (l) =>
            l.userId.equals(userId) &
            l.settled.equals(false) &
            l.deletedAt.isNull(),
      );

    return query.watch().map(_computeSummary);
  }

  @override
  Future<LedgerSummary> getOpenSummary({String userId = 'LOCAL'}) async {
    final query = _db.select(_db.ledgerEntries)
      ..where(
        (l) =>
            l.userId.equals(userId) &
            l.settled.equals(false) &
            l.deletedAt.isNull(),
      );

    final rows = await query.get();
    return _computeSummary(rows);
  }

  @override
  Future<List<LedgerEntry>> saveSplit({
    required SplitResult splitResult,
    required String localDate,
    String? note,
    String userId = 'LOCAL',
    String Function()? idGenerator,
  }) async {
    final lentShares = splitResult.lentEntries;
    if (lentShares.isEmpty) {
      return const [];
    }

    final now = clock.now();
    final nowUtcIso = now.toUtc().toIso8601String();
    final generateId = idGenerator ?? generateUuidV4;

    final createdEntries = <LedgerEntry>[];

    await _db.transaction(() async {
      for (final share in lentShares) {
        final entryId = generateId();
        final entry = LedgerEntry(
          id: entryId,
          userId: userId,
          person: share.name,
          amount: share.share,
          currency: share.share.currency,
          type: LedgerType.lent,
          note: note,
          settled: false,
          localDate: localDate,
          createdAt: now,
          clientUpdatedAt: now,
        );

        await _db
            .into(_db.ledgerEntries)
            .insert(
              db.LedgerEntriesCompanion.insert(
                id: entry.id,
                userId: Value(entry.userId),
                person: entry.person,
                amountMinor: entry.amount.minorUnits,
                currency: Value(entry.currency),
                type: entry.type.wireValue,
                note: Value(entry.note),
                settled: const Value(false),
                localDate: entry.localDate,
                createdAt: nowUtcIso,
                clientUpdatedAt: nowUtcIso,
              ),
            );

        await _enqueueOutbox('ledger_entries', entry.id, nowUtcIso);
        createdEntries.add(entry);
      }
    });

    return createdEntries;
  }

  SimpleSelectStatement<db.$LedgerEntriesTable, db.LedgerEntry>
  _buildEntriesQuery({
    required String userId,
    LedgerType? type,
    bool? settled,
  }) {
    return _db.select(_db.ledgerEntries)
      ..where(
        (l) =>
            l.userId.equals(userId) &
            l.deletedAt.isNull() &
            (type != null
                ? l.type.equals(type.wireValue)
                : const Constant(true)) &
            (settled != null
                ? l.settled.equals(settled)
                : const Constant(true)),
      )
      ..orderBy([
        (l) => OrderingTerm.desc(l.localDate),
        (l) => OrderingTerm.desc(l.createdAt),
      ]);
  }

  LedgerSummary _computeSummary(List<db.LedgerEntry> rows) {
    var lentEtb = 0;
    var borrowedEtb = 0;
    var lentUsd = 0;
    var borrowedUsd = 0;
    var openLentCount = 0;
    var openBorrowedCount = 0;

    for (final row in rows) {
      final isLent = row.type == LedgerType.lent.wireValue;
      final isUsd = row.currency == 'USD';

      if (isUsd) {
        if (isLent) {
          lentUsd += row.amountMinor;
          openLentCount++;
        } else {
          borrowedUsd += row.amountMinor;
          openBorrowedCount++;
        }
      } else {
        if (isLent) {
          lentEtb += row.amountMinor;
          openLentCount++;
        } else {
          borrowedEtb += row.amountMinor;
          openBorrowedCount++;
        }
      }
    }

    return LedgerSummary(
      totalLentEtb: Money.fromMinorUnits(lentEtb, currency: 'ETB'),
      totalBorrowedEtb: Money.fromMinorUnits(borrowedEtb, currency: 'ETB'),
      totalLentUsd: Money.fromMinorUnits(lentUsd, currency: 'USD'),
      totalBorrowedUsd: Money.fromMinorUnits(borrowedUsd, currency: 'USD'),
      openLentCount: openLentCount,
      openBorrowedCount: openBorrowedCount,
    );
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

  LedgerEntry _mapToDomain(db.LedgerEntry row) {
    return LedgerEntry(
      id: row.id,
      userId: row.userId,
      person: row.person,
      amount: Money.fromMinorUnits(row.amountMinor, currency: row.currency),
      currency: row.currency,
      type: LedgerType.fromString(row.type),
      note: row.note,
      settled: row.settled,
      localDate: row.localDate,
      createdAt: DateTime.parse(row.createdAt),
      clientUpdatedAt: DateTime.parse(row.clientUpdatedAt),
      deletedAt: row.deletedAt != null ? DateTime.parse(row.deletedAt!) : null,
    );
  }
}
