import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/data/repositories/session_repository.dart';
import 'package:haqly_mobile/domain/models/auth_state.dart';

void main() {
  group('TASK-031: LocalSessionRepository', () {
    test('initial empty storage returns unauthenticated state', () async {
      final repo = LocalSessionRepository.inMemory();
      final state = await repo.restoreSession();

      expect(state.isLoading, isFalse);
      expect(state.isGuest, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.hasSession, isFalse);
    });

    test(
      'setGuestMode persists guest sentinel and restores as guest',
      () async {
        final repo = LocalSessionRepository.inMemory();
        await repo.setGuestMode();

        final state = await repo.restoreSession();
        expect(state.isGuest, isTrue);
        expect(state.userId, AuthState.localSentinel);
        expect(state.hasSession, isTrue);
        expect(state.isAuthenticated, isFalse);
      },
    );

    test('clearSession resets guest state back to unauthenticated', () async {
      final repo = LocalSessionRepository.inMemory(isGuest: true);
      final initial = await repo.restoreSession();
      expect(initial.isGuest, isTrue);

      await repo.clearSession();
      final cleared = await repo.restoreSession();
      expect(cleared.isGuest, isFalse);
      expect(cleared.hasSession, isFalse);
    });

    test(
      'pre-seeded authenticated user restores with expected userId',
      () async {
        final repo = LocalSessionRepository.inMemory(userId: 'user_xyz_123');
        final state = await repo.restoreSession();

        expect(state.isAuthenticated, isTrue);
        expect(state.isGuest, isFalse);
        expect(state.userId, 'user_xyz_123');
        expect(state.hasSession, isTrue);
      },
    );
  });
}
