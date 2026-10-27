import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haqly_mobile/data/repositories/account_repository.dart';
import 'package:haqly_mobile/data/repositories/auth_repository.dart';
import 'package:haqly_mobile/data/repositories/session_repository.dart';
import 'package:haqly_mobile/domain/models/account_choice.dart';
import 'package:haqly_mobile/domain/models/auth_result.dart';
import 'package:haqly_mobile/domain/models/auth_state.dart';

/// Provider for the [SessionRepository].
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return LocalSessionRepository();
});

/// Provider for the [AuthRepository] (defaults to FakeAuthRepository for testing/offline,
/// overridden in real app with SupabaseAuthRepository).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FakeAuthRepository();
});

/// Provider for the [AccountRepository] managing upgrades and account conflict resolution.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return FakeAccountRepository();
});

/// Riverpod notifier managing identity, guest sentinel, and session restore.
/// Follows docs/ARCHITECTURE.md Section 7 and PRD FR-A1 / FR-A3 / FR-A4 / FR-A5 / FR-A6.
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

  /// Signs in anonymously to obtain a stable cloud identifier and adopts
  /// any existing LOCAL guest records.
  Future<AuthResult> signInAnonymously({
    Future<void> Function(String newUserId)? onAdopt,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    final result = await authRepo.signInAnonymously();

    if (result.isSuccess && result.userId != null) {
      if (onAdopt != null) {
        await onAdopt(result.userId!);
      }
      final sessionRepo = ref.read(sessionRepositoryProvider);
      await sessionRepo.setAuthenticatedUser(
        userId: result.userId!,
        email: result.email,
      );
      state = AuthState.authenticated(
        userId: result.userId!,
        email: result.email,
      );
    }
    return result;
  }

  /// Upgrades active guest mode by linking an email and password.
  /// Follows PRD FR-A4 and docs/ARCHITECTURE.md Section 6.
  Future<AuthResult> upgradeWithEmail({
    required String email,
    required String password,
  }) async {
    final accountRepo = ref.read(accountRepositoryProvider);
    final result = await accountRepo.upgradeWithEmail(
      email: email,
      password: password,
    );

    if (result.isSuccess &&
        !result.requiresVerification &&
        result.userId != null) {
      state = AuthState.authenticated(
        userId: result.userId!,
        email: result.email,
      );
    }
    return result;
  }

  /// Upgrades active guest mode by linking Google authentication.
  /// Follows PRD FR-A4 and docs/ARCHITECTURE.md Section 6.
  Future<AuthResult> upgradeWithGoogle() async {
    final accountRepo = ref.read(accountRepositoryProvider);
    final result = await accountRepo.upgradeWithGoogle();

    if (result.isSuccess && result.userId != null) {
      state = AuthState.authenticated(
        userId: result.userId!,
        email: result.email,
      );
    }
    return result;
  }

  /// Resolves an existing account conflict when upgrading with an email that is already registered (M4).
  Future<AuthResult> resolveExistingAccount({
    required String email,
    required String password,
    required ExistingAccountChoice choice,
  }) async {
    final accountRepo = ref.read(accountRepositoryProvider);
    final result = await accountRepo.resolveExistingAccount(
      email: email,
      password: password,
      choice: choice,
    );

    if (result.isSuccess && result.userId != null) {
      state = AuthState.authenticated(
        userId: result.userId!,
        email: result.email,
      );
    }
    return result;
  }

  /// Checks whether the device contains local guest data.
  Future<bool> hasGuestData() async {
    final accountRepo = ref.read(accountRepositoryProvider);
    return accountRepo.hasGuestData();
  }

  /// Registers a new user with email and password.
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    final result = await authRepo.signUpWithEmail(
      email: email,
      password: password,
    );

    if (result.isSuccess &&
        !result.requiresVerification &&
        result.userId != null) {
      final sessionRepo = ref.read(sessionRepositoryProvider);
      await sessionRepo.setAuthenticatedUser(
        userId: result.userId!,
        email: result.email,
      );
      state = AuthState.authenticated(
        userId: result.userId!,
        email: result.email,
      );
    }
    return result;
  }

  /// Signs in an existing user with email and password.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    final result = await authRepo.signInWithEmail(
      email: email,
      password: password,
    );

    if (result.isSuccess && result.userId != null) {
      final sessionRepo = ref.read(sessionRepositoryProvider);
      await sessionRepo.setAuthenticatedUser(
        userId: result.userId!,
        email: result.email,
      );
      state = AuthState.authenticated(
        userId: result.userId!,
        email: result.email,
      );
    }
    return result;
  }

  /// Signs in using Google authentication.
  /// Automatically adopts existing device guest data to the authenticated account if present.
  Future<AuthResult> signInWithGoogle({bool adoptGuestData = true}) async {
    final authRepo = ref.read(authRepositoryProvider);
    final result = await authRepo.signInWithGoogle();

    if (result.isSuccess && result.userId != null) {
      if (adoptGuestData) {
        final accountRepo = ref.read(accountRepositoryProvider);
        if (await accountRepo.hasGuestData()) {
          await accountRepo.adoptGuestData(newUserId: result.userId!);
        }
      }
      final sessionRepo = ref.read(sessionRepositoryProvider);
      await sessionRepo.setAuthenticatedUser(
        userId: result.userId!,
        email: result.email,
      );
      state = AuthState.authenticated(
        userId: result.userId!,
        email: result.email,
      );
    }
    return result;
  }

  /// Verifies email verification OTP code.
  Future<AuthResult> verifyOtp({
    required String email,
    required String token,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    final result = await authRepo.verifyEmailOtp(email: email, token: token);

    if (result.isSuccess && result.userId != null) {
      final sessionRepo = ref.read(sessionRepositoryProvider);
      await sessionRepo.setAuthenticatedUser(
        userId: result.userId!,
        email: result.email,
      );
      state = AuthState.authenticated(
        userId: result.userId!,
        email: result.email,
      );
    }
    return result;
  }

  /// Resends an OTP verification token.
  Future<AuthResult> resendOtp({required String email}) async {
    final authRepo = ref.read(authRepositoryProvider);
    return authRepo.resendOtp(email: email);
  }

  /// Sends a password recovery OTP to the given email address.
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    final authRepo = ref.read(authRepositoryProvider);
    return authRepo.sendPasswordResetEmail(email: email);
  }

  /// Verifies password recovery OTP and updates the account password.
  Future<AuthResult> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    return authRepo.resetPasswordWithOtp(
      email: email,
      token: token,
      newPassword: newPassword,
    );
  }

  /// Signs out and resets session state.
  Future<void> signOut() async {
    final authRepo = ref.read(authRepositoryProvider);
    final sessionRepo = ref.read(sessionRepositoryProvider);
    await authRepo.signOut();
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
