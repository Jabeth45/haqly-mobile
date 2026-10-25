import 'package:drift/drift.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/remote/remote_gateway.dart';
import 'package:haqly_mobile/data/remote/remote_mappers.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';

/// Result summary of a pull synchronization run.
class PullResult {
  const PullResult({
    this.pulledCount = 0,
    this.insertedCount = 0,
    this.updatedCount = 0,
    this.tombstoneCount = 0,
    this.isOffline = false,
    this.skippedUnauthenticated = false,
  });

  final int pulledCount;
  final int insertedCount;
  final int updatedCount;
  final int tombstoneCount;
  final bool isOffline;
  final bool skippedUnauthenticated;

  @override
  String toString() =>
      'PullResult(pulled: $pulledCount, inserted: $insertedCount, updated: $updatedCount, tombstones: $tombstoneCount, isOffline: $isOffline)';
}

/// Orchestrates pulling remote updates down to local SQLite using (updated_at, id) cursors.
/// Follows docs/ARCHITECTURE.md Section 4 and docs/RULES.md.
class PullService {
  PullService({
    required this.db,
    required this.outboxQueue,
    required this.remoteGateway,
  });

  final AppDatabase db;
  final OutboxQueue outboxQueue;
  final RemoteGateway remoteGateway;

  static const List<String> syncTables = [
    'expenses',
    'check_items',
    'ledger_entries',
    'budgets',
    'contacts',
    'user_categories',
  ];

  bool _isPulling = false;

  /// Whether a pull operation is currently active.
  bool get isPulling => _isPulling;

  /// Pulls remote changes across all sync tables using cursors stored in `sync_meta`.
  /// Applies inserts, updates, and tombstones (deleted_at).
  /// Concurrency-safe: ignores overlapping calls.
  Future<PullResult> pull({int batchSize = 500}) async {
    if (_isPulling) {
      return const PullResult();
    }

    _isPulling = true;
    try {
      if (!remoteGateway.isAuthenticated) {
        return const PullResult(skippedUnauthenticated: true);
      }

      var totalPulled = 0;
      var totalInserted = 0;
      var totalUpdated = 0;
      var totalTombstones = 0;

      for (final table in syncTables) {
        var hasMore = true;

        while (hasMore) {
          final meta = await (db.select(
            db.syncMeta,
          )..where((m) => m.recordTable.equals(table))).getSingleOrNull();

          List<Map<String, dynamic>> page;
          try {
            page = await remoteGateway.pull(
              table,
              cursorUpdatedAt: meta?.cursorUpdatedAt,
              cursorId: meta?.cursorId,
              limit: batchSize,
            );
          } on SyncOfflineException {
            return PullResult(
              pulledCount: totalPulled,
              insertedCount: totalInserted,
              updatedCount: totalUpdated,
              tombstoneCount: totalTombstones,
              isOffline: true,
            );
          }

          if (page.isEmpty) {
            hasMore = false;
            break;
          }

          totalPulled += page.length;

          // Apply remote batch inside transaction
          await db.transaction(() async {
            for (final remoteRow in page) {
              final result = await _applyRemoteRow(table, remoteRow);
              if (result == _ApplyResult.inserted) totalInserted++;
              if (result == _ApplyResult.updated) totalUpdated++;
              if (result == _ApplyResult.tombstone) totalTombstones++;
            }

            // Update pull cursor to last record in this batch
            final lastRecord = page.last;
            final lastUpdatedAt = lastRecord['updated_at']?.toString();
            final lastId = lastRecord['id']?.toString();

            if (lastUpdatedAt != null) {
              await db
                  .into(db.syncMeta)
                  .insertOnConflictUpdate(
                    SyncMetaCompanion(
                      recordTable: Value(table),
                      cursorUpdatedAt: Value(lastUpdatedAt),
                      cursorId: Value(lastId),
                    ),
                  );
            }
          });

          if (page.length < batchSize) {
            hasMore = false;
          }
        }
      }

      return PullResult(
        pulledCount: totalPulled,
        insertedCount: totalInserted,
        updatedCount: totalUpdated,
        tombstoneCount: totalTombstones,
        isOffline: false,
      );
    } finally {
      _isPulling = false;
    }
  }

  /// Applies a single remote record to the local SQLite table.
  /// Resolves conflicts: if local row has an un-pushed newer edit, preserves local.
  Future<_ApplyResult> _applyRemoteRow(
    String tableName,
    Map<String, dynamic> remote,
  ) async {
    final rowId = remote['id'] as String;
    final remoteClientUpdatedAt = remote['client_updated_at'] as String? ?? '';
    final isTombstone = remote['deleted_at'] != null;

    // Check if local row already exists and whether an outbox entry is pending
    final existingLocalUpdatedAt = await _getLocalClientUpdatedAt(
      tableName,
      rowId,
    );

    if (existingLocalUpdatedAt == null) {
      // Record does not exist locally; insert it
      await _insertRemoteRow(tableName, remote);
      return isTombstone ? _ApplyResult.tombstone : _ApplyResult.inserted;
    }

    // Record exists locally: check if local has a pending outbox edit that is strictly newer
    final hasPendingOutbox = await _hasPendingOutbox(tableName, rowId);
    if (hasPendingOutbox &&
        existingLocalUpdatedAt.compareTo(remoteClientUpdatedAt) > 0) {
      // Local edit is newer and awaiting push; preserve local
      return _ApplyResult.skipped;
    }

    // Remote is newer or equal (or local has no pending edit): overwrite local
    await _updateRemoteRow(tableName, remote);

    // If local had a pending outbox entry for this row and remote has accepted or surpassed it,
    // clear the outbox entry to prevent redundant upserts
    if (hasPendingOutbox &&
        remoteClientUpdatedAt.compareTo(existingLocalUpdatedAt) >= 0) {
      await outboxQueue.deleteByRow(tableName, rowId);
    }

    return isTombstone ? _ApplyResult.tombstone : _ApplyResult.updated;
  }

  Future<bool> _hasPendingOutbox(String tableName, String rowId) async {
    final count =
        await (db.selectOnly(db.outbox)
              ..addColumns([db.outbox.id.count()])
              ..where(
                db.outbox.recordTable.equals(tableName) &
                    db.outbox.rowId.equals(rowId),
              ))
            .map((r) => r.read(db.outbox.id.count()))
            .getSingle();
    return (count ?? 0) > 0;
  }

  Future<String?> _getLocalClientUpdatedAt(
    String tableName,
    String rowId,
  ) async {
    switch (tableName) {
      case 'expenses':
        final r = await (db.select(
          db.expenses,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return r?.clientUpdatedAt;
      case 'check_items':
        final r = await (db.select(
          db.checkItems,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return r?.clientUpdatedAt;
      case 'ledger_entries':
        final r = await (db.select(
          db.ledgerEntries,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return r?.clientUpdatedAt;
      case 'budgets':
        final r = await (db.select(
          db.budgets,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return r?.clientUpdatedAt;
      case 'contacts':
        final r = await (db.select(
          db.contacts,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return r?.clientUpdatedAt;
      case 'user_categories':
        final r = await (db.select(
          db.userCategories,
        )..where((t) => t.id.equals(rowId))).getSingleOrNull();
        return r?.clientUpdatedAt;
      default:
        return null;
    }
  }

  Future<void> _insertRemoteRow(
    String tableName,
    Map<String, dynamic> remote,
  ) async {
    switch (tableName) {
      case 'expenses':
        await db
            .into(db.expenses)
            .insert(RemoteMappers.expenseFromRemote(remote));
        break;
      case 'check_items':
        await db
            .into(db.checkItems)
            .insert(RemoteMappers.checkItemFromRemote(remote));
        break;
      case 'ledger_entries':
        await db
            .into(db.ledgerEntries)
            .insert(RemoteMappers.ledgerEntryFromRemote(remote));
        break;
      case 'budgets':
        await db
            .into(db.budgets)
            .insert(RemoteMappers.budgetFromRemote(remote));
        break;
      case 'contacts':
        await db
            .into(db.contacts)
            .insert(RemoteMappers.contactFromRemote(remote));
        break;
      case 'user_categories':
        await db
            .into(db.userCategories)
            .insert(RemoteMappers.userCategoryFromRemote(remote));
        break;
    }
  }

  Future<void> _updateRemoteRow(
    String tableName,
    Map<String, dynamic> remote,
  ) async {
    switch (tableName) {
      case 'expenses':
        await db
            .into(db.expenses)
            .insertOnConflictUpdate(RemoteMappers.expenseFromRemote(remote));
        break;
      case 'check_items':
        await db
            .into(db.checkItems)
            .insertOnConflictUpdate(RemoteMappers.checkItemFromRemote(remote));
        break;
      case 'ledger_entries':
        await db
            .into(db.ledgerEntries)
            .insertOnConflictUpdate(
              RemoteMappers.ledgerEntryFromRemote(remote),
            );
        break;
      case 'budgets':
        await db
            .into(db.budgets)
            .insertOnConflictUpdate(RemoteMappers.budgetFromRemote(remote));
        break;
      case 'contacts':
        await db
            .into(db.contacts)
            .insertOnConflictUpdate(RemoteMappers.contactFromRemote(remote));
        break;
      case 'user_categories':
        await db
            .into(db.userCategories)
            .insertOnConflictUpdate(
              RemoteMappers.userCategoryFromRemote(remote),
            );
        break;
    }
  }
}

enum _ApplyResult { inserted, updated, tombstone, skipped }
