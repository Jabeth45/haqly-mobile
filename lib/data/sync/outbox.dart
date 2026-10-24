import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' as db;

/// Domain representation of an outbox sync pointer.
/// Pointers reference the local database row rather than storing stale payloads.
/// Follows docs/ARCHITECTURE.md Section 4 and docs/RULES.md.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.recordTable,
    required this.rowId,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final int id;
  final String recordTable;
  final String rowId;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  bool get hasFailed => attempts > 0;

  OutboxEntry copyWith({
    int? id,
    String? recordTable,
    String? rowId,
    DateTime? createdAt,
    int? attempts,
    String? lastError,
  }) {
    return OutboxEntry(
      id: id ?? this.id,
      recordTable: recordTable ?? this.recordTable,
      rowId: rowId ?? this.rowId,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OutboxEntry &&
        id == other.id &&
        recordTable == other.recordTable &&
        rowId == other.rowId &&
        createdAt == other.createdAt &&
        attempts == other.attempts &&
        lastError == other.lastError;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      recordTable.hashCode ^
      rowId.hashCode ^
      createdAt.hashCode ^
      attempts.hashCode ^
      lastError.hashCode;

  @override
  String toString() =>
      'OutboxEntry(id: $id, table: $recordTable, rowId: $rowId, attempts: $attempts, lastError: $lastError)';
}

/// Exponential backoff configuration for retrying failed outbox entries.
class BackoffPolicy {
  const BackoffPolicy({
    this.initialDelay = const Duration(seconds: 2),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
  });

  final Duration initialDelay;
  final double multiplier;
  final Duration maxDelay;

  /// Calculates backoff duration based on number of failed attempts.
  /// attempts == 0 returns [Duration.zero].
  /// attempts >= 1 returns initialDelay * (multiplier ^ (attempts - 1)), capped at maxDelay.
  Duration getDelay(int attempts) {
    if (attempts <= 0) return Duration.zero;

    final factor = math.pow(multiplier, attempts - 1).toDouble();
    final delayMs = (initialDelay.inMilliseconds * factor).round();

    if (delayMs >= maxDelay.inMilliseconds) {
      return maxDelay;
    }
    return Duration(milliseconds: delayMs);
  }

  /// Checks whether an entry is ready to be attempted at [now].
  bool isReady(OutboxEntry entry, DateTime now) {
    if (entry.attempts <= 0) return true;
    final delay = getDelay(entry.attempts);
    final nextAttemptAt = entry.createdAt.add(delay);
    return !now.isBefore(nextAttemptAt);
  }
}

/// Manages the local outbox queue in SQLite for offline-first synchronization.
class OutboxQueue {
  OutboxQueue(
    this._db, {
    this.clock = const SystemClock(),
    this.backoffPolicy = const BackoffPolicy(),
  });

  final db.AppDatabase _db;
  final Clock clock;
  final BackoffPolicy backoffPolicy;

  /// Atomically enqueues a pointer for [tableName] and [rowId].
  /// If a pointer already exists for the same table and rowId, coalesces:
  /// updates [createdAt] to now, resets [attempts] to 0, and clears [lastError].
  Future<int> enqueue(
    String tableName,
    String rowId, {
    DateTime? now,
  }) async {
    final nowUtc = (now ?? clock.now()).toUtc();
    final nowUtcIso = nowUtc.toIso8601String();

    return _db.transaction(() async {
      final existing = await (_db.select(_db.outbox)..where(
            (o) => o.recordTable.equals(tableName) & o.rowId.equals(rowId),
          ))
          .getSingleOrNull();

      if (existing == null) {
        return _db.into(_db.outbox).insert(
              db.OutboxCompanion.insert(
                recordTable: tableName,
                rowId: rowId,
                createdAt: nowUtcIso,
              ),
            );
      } else {
        await (_db.update(_db.outbox)..where((o) => o.id.equals(existing.id)))
            .write(
          db.OutboxCompanion(
            createdAt: Value(nowUtcIso),
            attempts: const Value(0),
            lastError: const Value(null),
          ),
        );
        return existing.id;
      }
    });
  }

  /// Records a failed sync attempt for [outboxId], incrementing attempts,
  /// updating [lastError], and resetting [createdAt] to [failedAt] for backoff calculation.
  Future<void> recordFailure(
    int outboxId, {
    required String error,
    DateTime? failedAt,
  }) async {
    final failTimeUtcIso =
        (failedAt ?? clock.now()).toUtc().toIso8601String();

    await _db.transaction(() async {
      final entry = await (_db.select(_db.outbox)
            ..where((o) => o.id.equals(outboxId)))
          .getSingleOrNull();

      if (entry == null) return;

      await (_db.update(_db.outbox)..where((o) => o.id.equals(outboxId))).write(
        db.OutboxCompanion(
          attempts: Value(entry.attempts + 1),
          lastError: Value(error),
          createdAt: Value(failTimeUtcIso),
        ),
      );
    });
  }

  /// Deletes a successfully synced entry by its primary key [outboxId].
  Future<bool> deleteEntry(int outboxId) async {
    final deleted = await (_db.delete(_db.outbox)
          ..where((o) => o.id.equals(outboxId)))
        .go();
    return deleted > 0;
  }

  /// Deletes all outbox entries for a given [tableName] and [rowId].
  Future<int> deleteByRow(String tableName, String rowId) async {
    return (_db.delete(_db.outbox)
          ..where(
            (o) => o.recordTable.equals(tableName) & o.rowId.equals(rowId),
          ))
        .go();
  }

  /// Retrieves pending entries whose backoff delay has elapsed at [now],
  /// ordered by id ASC (FIFO).
  Future<List<OutboxEntry>> getReadyEntries({
    int limit = 50,
    DateTime? now,
  }) async {
    final currentTime = now ?? clock.now();
    final rows = await (_db.select(_db.outbox)
          ..orderBy([(o) => OrderingTerm.asc(o.id)])
          ..limit(limit))
        .get();

    final allEntries = rows.map(_mapToDomain).toList();
    return allEntries
        .where((entry) => backoffPolicy.isReady(entry, currentTime))
        .toList();
  }

  /// Retrieves all pending outbox entries ordered by id ASC (FIFO).
  Future<List<OutboxEntry>> getAllEntries() async {
    final rows = await (_db.select(_db.outbox)
          ..orderBy([(o) => OrderingTerm.asc(o.id)]))
        .get();
    return rows.map(_mapToDomain).toList();
  }

  /// Returns the current count of pending outbox entries.
  Future<int> getPendingCount() async {
    final countExp = _db.outbox.id.count();
    final query = _db.selectOnly(_db.outbox)..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  /// Watches the count of pending outbox entries reactively.
  Stream<int> watchPendingCount() {
    final countExp = _db.outbox.id.count();
    final query = _db.selectOnly(_db.outbox)..addColumns([countExp]);
    return query
        .watchSingle()
        .map((row) => row.read(countExp) ?? 0)
        .distinct();
  }

  /// Resets attempts to 0 and clears lastError for all pending outbox entries
  /// (or a single entry if [outboxId] is specified).
  /// Used for manual tap-to-retry actions.
  Future<void> resetAttempts({int? outboxId}) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      final updateQuery = _db.update(_db.outbox);
      if (outboxId != null) {
        updateQuery.where((o) => o.id.equals(outboxId));
      }
      await updateQuery.write(
        db.OutboxCompanion(
          attempts: const Value(0),
          lastError: const Value(null),
          createdAt: Value(nowUtcIso),
        ),
      );
    });
  }

  OutboxEntry _mapToDomain(db.OutboxData row) {
    return OutboxEntry(
      id: row.id,
      recordTable: row.recordTable,
      rowId: row.rowId,
      createdAt: DateTime.parse(row.createdAt),
      attempts: row.attempts,
      lastError: row.lastError,
    );
  }
}
