import 'dart:async';

import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/remote/remote_gateway.dart';
import 'package:haqly_mobile/data/remote/remote_mappers.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';

/// Summary result of an outbox drain run.
class DrainResult {
  const DrainResult({
    this.attemptedCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.isOffline = false,
    this.skippedUnauthenticated = false,
  });

  final int attemptedCount;
  final int successCount;
  final int failureCount;
  final bool isOffline;
  final bool skippedUnauthenticated;

  bool get hasFailures => failureCount > 0;
  bool get isClean => failureCount == 0 && !isOffline;

  @override
  String toString() =>
      'DrainResult(attempted: $attemptedCount, success: $successCount, failures: $failureCount, isOffline: $isOffline)';
}

/// Orchestrates background synchronization between local Drift SQLite and the remote backend.
/// Drains local outbox pointers by reading current row state and pushing to [RemoteGateway].
/// Follows docs/ARCHITECTURE.md Section 4 and docs/RULES.md.
class SyncService {
  SyncService({
    required this.db,
    required this.outboxQueue,
    required this.remoteGateway,
    this.clock = const SystemClock(),
  });

  final AppDatabase db;
  final OutboxQueue outboxQueue;
  final RemoteGateway remoteGateway;
  final Clock clock;

  bool _isDraining = false;

  /// Whether a drain cycle is currently in progress.
  bool get isDraining => _isDraining;

  /// Drains pending outbox pointers by fetching ready items, constructing current
  /// payloads from local SQLite, and pushing via [RemoteGateway].
  /// Concurrency-safe: prevents overlapping runs.
  Future<DrainResult> drain({int batchSize = 50}) async {
    if (_isDraining) {
      return const DrainResult();
    }

    _isDraining = true;
    try {
      if (!remoteGateway.isAuthenticated) {
        return const DrainResult(skippedUnauthenticated: true);
      }

      final readyEntries = await outboxQueue.getReadyEntries(
        limit: batchSize,
        now: clock.now(),
      );

      if (readyEntries.isEmpty) {
        return const DrainResult();
      }

      var successCount = 0;
      var failureCount = 0;
      var isOffline = false;

      for (final entry in readyEntries) {
        final payload = await _buildPayload(entry.recordTable, entry.rowId);

        if (payload == null) {
          // Row was permanently removed locally; discard stale outbox pointer
          await outboxQueue.deleteEntry(entry.id);
          continue;
        }

        // If row is marked with local guest sentinel, skip pushing until adopted
        if (payload['user_id'] == 'LOCAL') {
          continue;
        }

        try {
          await remoteGateway.upsert(entry.recordTable, payload);
          await outboxQueue.deleteEntry(entry.id);
          successCount++;
        } on SyncOfflineException {
          // Network connection unreachable; halt drain immediately
          isOffline = true;
          break;
        } catch (e) {
          failureCount++;
          await outboxQueue.recordFailure(
            entry.id,
            error: e.toString(),
            failedAt: clock.now(),
          );
        }
      }

      return DrainResult(
        attemptedCount: successCount + failureCount,
        successCount: successCount,
        failureCount: failureCount,
        isOffline: isOffline,
      );
    } finally {
      _isDraining = false;
    }
  }

  /// Builds a remote JSON payload for a given local row pointer.
  Future<Map<String, dynamic>?> _buildPayload(
    String tableName,
    String rowId,
  ) async {
    switch (tableName) {
      case 'expenses':
        final row = await (db.select(
          db.expenses,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return row != null ? RemoteMappers.expenseToRemote(row) : null;

      case 'check_items':
        final row = await (db.select(
          db.checkItems,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return row != null ? RemoteMappers.checkItemToRemote(row) : null;

      case 'ledger_entries':
        final row = await (db.select(
          db.ledgerEntries,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return row != null ? RemoteMappers.ledgerEntryToRemote(row) : null;

      case 'budgets':
        final row = await (db.select(
          db.budgets,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return row != null ? RemoteMappers.budgetToRemote(row) : null;

      case 'contacts':
        final row = await (db.select(
          db.contacts,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return row != null ? RemoteMappers.contactToRemote(row) : null;

      case 'user_categories':
        final row = await (db.select(
          db.userCategories,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return row != null ? RemoteMappers.userCategoryToRemote(row) : null;

      default:
        return null;
    }
  }
}
