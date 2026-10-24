import 'dart:async';

import 'package:haqly_mobile/core/services/connectivity_service.dart';

/// Callback invoked when a synchronization cycle is triggered.
typedef SyncExecutor = Future<void> Function();

/// Coordinates events that trigger data synchronization:
/// - Local writes (debounced ~2 seconds)
/// - App foregrounding / lifecycle resume (immediate)
/// - Connectivity regained hint (immediate)
/// - Pull-to-refresh / manual retry (immediate)
/// Follows docs/ARCHITECTURE.md Section 4 and docs/RULES.md.
class SyncTriggerCoordinator {
  SyncTriggerCoordinator({
    required this.onSync,
    this.connectivityService,
    this.debounceDuration = const Duration(seconds: 2),
  }) {
    if (connectivityService != null) {
      _connectivitySubscription = connectivityService!.onConnectivityChanged
          .listen((isOnline) {
            if (isOnline) {
              unawaited(requestSync(immediate: true));
            }
          });
    }
  }

  final SyncExecutor onSync;
  final ConnectivityService? connectivityService;
  final Duration debounceDuration;

  Timer? _debounceTimer;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isExecuting = false;
  int _syncCount = 0;

  /// Whether a debounced sync timer is currently pending.
  bool get hasPendingDebounce => _debounceTimer?.isActive ?? false;

  /// Total number of sync executions completed.
  int get syncCount => _syncCount;

  /// Requests a synchronization run.
  /// When [immediate] is false (default), debounces subsequent calls by [debounceDuration].
  /// When [immediate] is true, cancels pending timers and runs immediately.
  Future<void> requestSync({bool immediate = false}) async {
    if (immediate) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      await _execute();
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      unawaited(_execute());
    });
  }

  /// Triggered when the app is brought to the foreground / resumed from background.
  Future<void> onAppForegrounded() async {
    await requestSync(immediate: true);
  }

  Future<void> _execute() async {
    if (_isExecuting) return;

    _isExecuting = true;
    try {
      await onSync();
      _syncCount++;
    } finally {
      _isExecuting = false;
    }
  }

  /// Cancels active timers and stream subscriptions.
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
