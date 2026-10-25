import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haqly_mobile/data/repositories/session_repository.dart';
import 'package:haqly_mobile/domain/models/auth_state.dart';

/// Provider for the [SessionRepository].
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return LocalSessionRepository();
});

/// Riverpod notifier managing identity, guest sentinel, and session restore.
/// Follows docs/ARCHITECTURE.md Section 7 and FR-A3/FR-A6.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthState.initial();
  }

  Future<void> _restore() async {
    final sessionRepo = ref.read(sessionRepositoryProvider);
    final restored = await sessionRepo.restoreSession();
    state = restored;
  }

  /// Explicitly restore session state.
  Future<void> restore() async {
    final sessionRepo = ref.read(sessionRepositoryProvider);
    state = await sessionRepo.restoreSession();
  }

  /// Activates local guest mode using the LOCAL sentinel.
  Future<void> continueAsGuest() async {
    final sessionRepo = ref.read(sessionRepositoryProvider);
    await sessionRepo.setGuestMode();
    state = const AuthState.guest();
  }

  /// Signs out and resets session state.
  Future<void> signOut() async {
    final sessionRepo = ref.read(sessionRepositoryProvider);
    await sessionRepo.clearSession();
    state = const AuthState.unauthenticated();
  }
}

/// Provider for the reactive [AuthState].
final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Listenable adapter that notifies [GoRouter] when [AuthState] changes.
class AuthListenable extends ChangeNotifier {
  AuthListenable(Ref ref) {
    ref.listen<AuthState>(authStateProvider, (_, next) {
      notifyListeners();
    });
  }
}

/// Provider for the router refresh listenable.
final authListenableProvider = Provider<AuthListenable>((ref) {
  return AuthListenable(ref);
});
