import 'package:haqly_mobile/data/remote/remote_gateway.dart';

/// In-memory test double of [RemoteGateway] for verifying offline and sync behaviors.
class FakeRemoteGateway implements RemoteGateway {
  FakeRemoteGateway({
    this.isOnline = true,
    this.isAuthenticated = true,
    this.currentUserId = '00000000-0000-0000-0000-000000000001',
  });

  /// Whether the network is currently reachable.
  bool isOnline;

  /// Whether the client is currently authenticated.
  @override
  bool isAuthenticated;

  /// The active user ID.
  @override
  String? currentUserId;

  /// Specific table name to simulate failure for.
  String? failForTable;

  /// Specific rowId to simulate failure for.
  String? failForRowId;

  /// Number of times to fail before succeeding.
  int failAttemptsCount = 0;

  /// In-memory storage: tableName -> rowId -> payload map.
  final Map<String, Map<String, Map<String, dynamic>>> _remoteStore = {};

  /// Log of all individual upsert operations for assertions.
  final List<Map<String, dynamic>> upsertHistory = [];

  @override
  Future<void> upsert(String tableName, Map<String, dynamic> payload) async {
    if (!isOnline) {
      throw const SyncOfflineException('FakeRemote is offline');
    }

    final rowId = payload['id']?.toString();
    if (failForTable == tableName ||
        (failForRowId != null && failForRowId == rowId)) {
      if (failAttemptsCount > 0) {
        failAttemptsCount--;
        throw SyncException(
          'Simulated transient failure for $tableName:$rowId',
        );
      } else if (failAttemptsCount == 0 &&
          (failForTable != null || failForRowId != null)) {
        throw SyncException(
          'Simulated persistent failure for $tableName:$rowId',
        );
      }
    }

    if (rowId != null) {
      final copy = Map<String, dynamic>.from(payload);
      copy['updated_at'] ??=
          copy['client_updated_at'] ?? DateTime.now().toUtc().toIso8601String();
      _remoteStore.putIfAbsent(tableName, () => {})[rowId] = copy;
    }
    upsertHistory.add({
      'table': tableName,
      'payload': Map<String, dynamic>.from(payload),
    });
  }

  @override
  Future<void> upsertBatch(
    String tableName,
    List<Map<String, dynamic>> payloads,
  ) async {
    for (final payload in payloads) {
      await upsert(tableName, payload);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pull(
    String tableName, {
    String? cursorUpdatedAt,
    String? cursorId,
    int limit = 500,
  }) async {
    if (!isOnline) {
      throw const SyncOfflineException('FakeRemote is offline');
    }

    final tableRows = _remoteStore[tableName]?.values.toList() ?? [];

    final filtered = tableRows.where((row) {
      if (cursorUpdatedAt == null) return true;
      final rowUpdatedAt = row['updated_at']?.toString() ?? '';
      final rowId = row['id']?.toString() ?? '';

      final cmp = rowUpdatedAt.compareTo(cursorUpdatedAt);
      if (cmp > 0) return true;
      if (cmp == 0 && cursorId != null) {
        return rowId.compareTo(cursorId) > 0;
      }
      return false;
    }).toList();

    filtered.sort((a, b) {
      final aUpdated = a['updated_at']?.toString() ?? '';
      final bUpdated = b['updated_at']?.toString() ?? '';
      final cmp = aUpdated.compareTo(bUpdated);
      if (cmp != 0) return cmp;
      final aId = a['id']?.toString() ?? '';
      final bId = b['id']?.toString() ?? '';
      return aId.compareTo(bId);
    });

    if (filtered.length > limit) {
      return filtered.sublist(0, limit);
    }
    return filtered;
  }

  /// Returns all stored rows for a given table.
  List<Map<String, dynamic>> rowsFor(String tableName) {
    return _remoteStore[tableName]?.values.toList() ?? [];
  }

  /// Returns a specific row by table and id.
  Map<String, dynamic>? getRow(String tableName, String rowId) {
    return _remoteStore[tableName]?[rowId];
  }

  /// Resets in-memory storage and failure simulations.
  void clear() {
    _remoteStore.clear();
    upsertHistory.clear();
    failForTable = null;
    failForRowId = null;
    failAttemptsCount = 0;
  }
}
