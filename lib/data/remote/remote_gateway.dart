/// Exceptions thrown during remote synchronization.
class SyncException implements Exception {
  const SyncException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'SyncException: $message';
}

/// Thrown when sync cannot reach the remote backend due to network unavailability.
class SyncOfflineException extends SyncException {
  const SyncOfflineException([
    super.message = 'Network is offline or unreachable',
  ]);
}

/// Abstract contract for sending and receiving records to/from the remote backend (Supabase).
/// Follows docs/ARCHITECTURE.md Section 4 and docs/RULES.md.
abstract class RemoteGateway {
  /// Whether an authenticated session currently exists.
  bool get isAuthenticated;

  /// The current user ID from the active session, or null if unauthenticated.
  String? get currentUserId;

  /// Pushes a single record payload to [tableName] on the remote backend via upsert.
  Future<void> upsert(String tableName, Map<String, dynamic> payload);

  /// Pushes a batch of record payloads to [tableName] on the remote backend via upsert.
  Future<void> upsertBatch(
    String tableName,
    List<Map<String, dynamic>> payloads,
  );

  /// Pulls a page of records updated since [cursorUpdatedAt] and [cursorId] for [tableName],
  /// ordered by `updated_at ASC, id ASC`.
  Future<List<Map<String, dynamic>>> pull(
    String tableName, {
    String? cursorUpdatedAt,
    String? cursorId,
    int limit = 500,
  });
}
