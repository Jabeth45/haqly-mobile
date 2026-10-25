import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/connectivity_service.dart';
import 'package:haqly_mobile/data/sync/sync_triggers.dart';

void main() {
  group('TASK-028: SyncTriggerCoordinator - Debounce & Coalescing', () {
    test('rapid successive calls coalesce into a single execution after debounce duration', () async {
      var callCount = 0;
      final coordinator = SyncTriggerCoordinator(
        onSync: () async => callCount++,
        debounceDuration: const Duration(milliseconds: 60),
      );

      // 3 rapid calls within 30ms
      unawaited(coordinator.requestSync());
      expect(coordinator.hasPendingDebounce, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 15));
      unawaited(coordinator.requestSync());

      await Future<void>.delayed(const Duration(milliseconds: 15));
      unawaited(coordinator.requestSync());

      // At 30ms, still pending and 0 calls made
      expect(callCount, 0);
      expect(coordinator.hasPendingDebounce, isTrue);

      // Wait 35ms (total 65ms; 35ms after last call) -> still waiting (needs 60ms after last call)
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(callCount, 0);

      // Wait remaining 35ms (70ms after last call) -> executes exactly once
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(callCount, 1);
      expect(coordinator.hasPendingDebounce, isFalse);

      coordinator.dispose();
    });

    test(
      'immediate request cancels pending debounce and executes immediately',
      () async {
        var callCount = 0;
        final coordinator = SyncTriggerCoordinator(
          onSync: () async => callCount++,
          debounceDuration: const Duration(milliseconds: 100),
        );

        // Debounced request started
        unawaited(coordinator.requestSync());
        expect(coordinator.hasPendingDebounce, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(callCount, 0);

        // User pulls to refresh or triggers immediate sync
        await coordinator.requestSync(immediate: true);

        // Immediate sync executed, timer cancelled
        expect(callCount, 1);
        expect(coordinator.hasPendingDebounce, isFalse);

        // Elapsing further time does not execute again
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(callCount, 1);

        coordinator.dispose();
      },
    );
  });

  group('TASK-028: SyncTriggerCoordinator - Connectivity Hint Trigger', () {
    test(
      'transitioning from offline to online triggers immediate sync',
      () async {
        var callCount = 0;
        final fakeConnectivity = FakeConnectivityService(
          initialConnected: false,
        );

        final coordinator = SyncTriggerCoordinator(
          onSync: () async => callCount++,
          connectivityService: fakeConnectivity,
        );

        expect(callCount, 0);

        // Reconnect to network
        fakeConnectivity.setConnected(true);
        await pumpEventQueue();

        expect(callCount, 1);

        coordinator.dispose();
        fakeConnectivity.dispose();
      },
    );

    test(
      'transitioning from online to offline does not trigger sync',
      () async {
        var callCount = 0;
        final fakeConnectivity = FakeConnectivityService(
          initialConnected: true,
        );

        final coordinator = SyncTriggerCoordinator(
          onSync: () async => callCount++,
          connectivityService: fakeConnectivity,
        );

        expect(callCount, 0);

        // Disconnect from network
        fakeConnectivity.setConnected(false);
        await pumpEventQueue();

        expect(callCount, 0);

        coordinator.dispose();
        fakeConnectivity.dispose();
      },
    );
  });

  group(
    'TASK-028: SyncTriggerCoordinator - App Lifecycle & Clean Disposal',
    () {
      test('onAppForegrounded triggers immediate sync', () async {
        var callCount = 0;
        final coordinator = SyncTriggerCoordinator(
          onSync: () async => callCount++,
        );

        await coordinator.onAppForegrounded();
        expect(callCount, 1);

        coordinator.dispose();
      });

      test(
        'dispose cancels active timer and prevents subsequent executions',
        () async {
          var callCount = 0;
          final coordinator = SyncTriggerCoordinator(
            onSync: () async => callCount++,
            debounceDuration: const Duration(milliseconds: 50),
          );

          unawaited(coordinator.requestSync());
          expect(coordinator.hasPendingDebounce, isTrue);

          coordinator.dispose();
          expect(coordinator.hasPendingDebounce, isFalse);

          await Future<void>.delayed(const Duration(milliseconds: 70));
          expect(callCount, 0);
        },
      );
    },
  );
}
