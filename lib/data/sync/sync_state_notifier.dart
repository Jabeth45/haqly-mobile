import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';
import 'package:haqly_mobile/data/sync/pull.dart';
import 'package:haqly_mobile/data/sync/sync_service.dart';
import 'package:haqly_mobile/data/sync/sync_state.dart';

/// Notifier driving the synchronization state machine:
/// `idle -> syncing -> idle | offline | error`.
/// Tracks outbox pending counts reactively and drives the header sync icon.
/// Follows docs/ARCHITECTURE.md Section 4 and docs/RULES.md.
class SyncStateNotifier extends ValueNotifier<SyncState> {
  SyncStateNotifier({
    required this.outboxQueue,
    required this.syncService,
    required this.pullService,
    this.clock = const SystemClock(),
  }) : super(const SyncState()) {
    _pendingSub = outboxQueue.watchPendingCount().listen((count) {
      value = value.copyWith(pendingCount: count);
    });
  }

  final OutboxQueue outboxQueue;
  final SyncService syncService;
  final PullService pullService;
  final Clock clock;

  StreamSubscription<int>? _pendingSub;

  /// Executes a full synchronization cycle:
  /// 1. Transitions state to [SyncStatus.syncing].
  /// 2. Pulls remote updates via [PullService].
  /// 3. Drains local outbox pointers via [SyncService].
  /// 4. Transitions to [SyncStatus.offline] if unreachable,
  ///    [SyncStatus.error] if failures occur, or [SyncStatus.idle] on clean completion.
  Future<void> runSync() async {
    if (value.isSyncing) return;

    value = value.copyWith(status: SyncStatus.syncing, lastError: () => null);

    // 1. Pull remote updates down to local SQLite
    final pullResult = await pullService.pull();
    if (pullResult.isOffline) {
      value = value.copyWith(status: SyncStatus.offline);
      return;
    }

    // 2. Drain local outbox pointers up to remote backend
    final drainResult = await syncService.drain();
    if (drainResult.isOffline) {
      value = value.copyWith(status: SyncStatus.offline);
      return;
    }

    if (drainResult.hasFailures) {
      value = value.copyWith(
        status: SyncStatus.error,
        lastError: () => 'Sync failed for ${drainResult.failureCount} item(s)',
      );
      return;
    }

    // 3. Clean sync completion
    value = value.copyWith(
      status: SyncStatus.idle,
      lastSyncedAt: () => clock.now(),
      lastError: () => null,
    );
  }

  /// Triggered by user tapping the warning / offline sync icon in the header.
  /// Resets backoff attempts on pending items and initiates an immediate sync run.
  Future<void> tapToRetry() async {
    await outboxQueue.resetAttempts();
    await runSync();
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _pendingSub = null;
    super.dispose();
  }
}
