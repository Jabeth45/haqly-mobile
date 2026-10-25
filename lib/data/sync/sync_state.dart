/// State machine enum for synchronization.
/// Follows docs/ARCHITECTURE.md Section 4 and docs/PRD.md FR-HM6.
enum SyncStatus {
  idle,
  syncing,
  offline,
  error;

  /// Whether the quiet sync icon should be displayed in the app header.
  /// Hidden when idle; visible only when offline, syncing, or in error.
  bool get isIconVisible => this != SyncStatus.idle;
}

/// Immutable state snapshot of data synchronization.
class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastError,
    this.lastSyncedAt,
  });

  final SyncStatus status;
  final int pendingCount;
  final String? lastError;
  final DateTime? lastSyncedAt;

  bool get isIconVisible => status.isIconVisible;
  bool get isSyncing => status == SyncStatus.syncing;
  bool get isOffline => status == SyncStatus.offline;
  bool get hasError => status == SyncStatus.error;
  bool get canRetry => hasError || isOffline;

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    String? Function()? lastError,
    DateTime? Function()? lastSyncedAt,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: lastError != null ? lastError() : this.lastError,
      lastSyncedAt: lastSyncedAt != null ? lastSyncedAt() : this.lastSyncedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncState &&
        status == other.status &&
        pendingCount == other.pendingCount &&
        lastError == other.lastError &&
        lastSyncedAt == other.lastSyncedAt;
  }

  @override
  int get hashCode =>
      status.hashCode ^
      pendingCount.hashCode ^
      lastError.hashCode ^
      lastSyncedAt.hashCode;

  @override
  String toString() =>
      'SyncState(status: $status, pendingCount: $pendingCount, lastError: $lastError)';
}
