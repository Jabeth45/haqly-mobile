import 'package:haqly_mobile/data/repositories/auth_repository.dart';
import 'package:haqly_mobile/data/repositories/session_repository.dart';
import 'package:haqly_mobile/data/sync/adopt.dart';
import 'package:haqly_mobile/data/sync/pull.dart';
import 'package:haqly_mobile/domain/models/account_choice.dart';
import 'package:haqly_mobile/domain/models/auth_result.dart';
import 'package:haqly_mobile/domain/models/auth_state.dart';

/// Contract for managing user account lifecycle, guest-to-account upgrades,
/// and conflict resolution per docs/ARCHITECTURE.md Section 4 & 6 and PRD FR-A4.
abstract class AccountRepository {
  /// Whether the device contains local guest data.
  Future<bool> hasGuestData({String guestUserId = AuthState.localSentinel});

  /// Total count of active guest rows on device.
  Future<int> countGuestData({String guestUserId = AuthState.localSentinel});

  /// Upgrades an active guest session by linking an email and password.
  /// Adopts local guest records and preserves history (M3).
  Future<AuthResult> upgradeWithEmail({
    required String email,
    required String password,
  });

  /// Upgrades an active guest session by linking Google identity.
  /// Adopts local guest records and preserves history (M3).
  Future<AuthResult> upgradeWithGoogle();

  /// Adopts active guest records to the specified [newUserId].
  Future<void> adoptGuestData({
    required String newUserId,
    String guestUserId = AuthState.localSentinel,
  });

  /// Resolves account conflict when upgrading with an email that already exists (M4).
  /// If [choice] == [ExistingAccountChoice.keepCloud]:
  ///   Local guest records are discarded and cloud data is hydrated into SQLite.
  /// If [choice] == [ExistingAccountChoice.replaceWithDevice]:
  ///   Local guest records are adopted to the authenticated user and queued for sync.
  Future<AuthResult> resolveExistingAccount({
    required String email,
    required String password,
    required ExistingAccountChoice choice,
    String guestUserId = AuthState.localSentinel,
  });
}

/// Production implementation of [AccountRepository].
class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({
    required this.adoptionService,
    required this.authRepository,
    required this.sessionRepository,
    required this.pullService,
  });

  final AdoptionService adoptionService;
  final AuthRepository authRepository;
  final SessionRepository sessionRepository;
  final PullService pullService;

  @override
  Future<bool> hasGuestData({
    String guestUserId = AuthState.localSentinel,
  }) async {
    return adoptionService.hasGuestData(guestUserId: guestUserId);
  }

  @override
  Future<int> countGuestData({
    String guestUserId = AuthState.localSentinel,
  }) async {
    return adoptionService.countGuestData(guestUserId: guestUserId);
  }

  @override
  Future<AuthResult> upgradeWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await authRepository.linkEmail(
      email: email,
      password: password,
    );

    if (result.emailAlreadyInUse) {
      return result;
    }

    if (result.isSuccess &&
        !result.requiresVerification &&
        result.userId != null) {
      // Adopt guest data to the permanent user identifier
      await adoptionService.adopt(newUserId: result.userId!);
      await sessionRepository.setAuthenticatedUser(
        userId: result.userId!,
        email: result.email,
      );
    }

    return result;
  }

  @override
  Future<AuthResult> upgradeWithGoogle() async {
    final result = await authRepository.linkGoogle();

    if (result.emailAlreadyInUse) {
      return result;
    }

    if (result.isSuccess && result.userId != null) {
      await adoptionService.adopt(newUserId: result.userId!);
      await sessionRepository.setAuthenticatedUser(
        userId: result.userId!,
        email: result.email,
      );
    }

    return result;
  }

  @override
  Future<void> adoptGuestData({
    required String newUserId,
    String guestUserId = AuthState.localSentinel,
  }) async {
    await adoptionService.adopt(newUserId: newUserId, fromUserId: guestUserId);
  }

  @override
  Future<AuthResult> resolveExistingAccount({
    required String email,
    required String password,
    required ExistingAccountChoice choice,
    String guestUserId = AuthState.localSentinel,
  }) async {
    // 1. Authenticate against existing credentials
    final authRes = await authRepository.signInWithEmail(
      email: email,
      password: password,
    );

    if (!authRes.isSuccess || authRes.userId == null) {
      return authRes;
    }

    final targetUserId = authRes.userId!;

    switch (choice) {
      case ExistingAccountChoice.keepCloud:
        // Discard local guest data, commit session, then hydrate from cloud
        await adoptionService.discardGuestData(guestUserId: guestUserId);
        await sessionRepository.setAuthenticatedUser(
          userId: targetUserId,
          email: authRes.email,
        );
        await pullService.pull();
        break;

      case ExistingAccountChoice.replaceWithDevice:
        // Adopt device data to the account and commit session
        await adoptionService.adopt(
          newUserId: targetUserId,
          fromUserId: guestUserId,
        );
        await sessionRepository.setAuthenticatedUser(
          userId: targetUserId,
          email: authRes.email,
        );
        break;
    }

    return authRes;
  }
}

/// In-memory fake implementation of [AccountRepository] for tests and defaults.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    bool initialHasGuestData = true,
    int initialCountGuestData = 5,
    Set<String>? existingRegisteredEmails,
  }) : _hasGuestData = initialHasGuestData,
       _guestCount = initialCountGuestData,
       existingRegisteredEmails =
           existingRegisteredEmails ?? {'existing@haqly.app'};

  bool _hasGuestData;
  int _guestCount;
  final Set<String> existingRegisteredEmails;
  bool isAdopted = false;
  bool isDiscarded = false;
  bool isHydratedFromCloud = false;

  @override
  Future<bool> hasGuestData({
    String guestUserId = AuthState.localSentinel,
  }) async {
    return _hasGuestData;
  }

  @override
  Future<int> countGuestData({
    String guestUserId = AuthState.localSentinel,
  }) async {
    return _guestCount;
  }

  @override
  Future<AuthResult> upgradeWithEmail({
    required String email,
    required String password,
  }) async {
    if (existingRegisteredEmails.contains(email.toLowerCase())) {
      return AuthResult.emailAlreadyInUse(email: email);
    }
    if (password.length < 6) {
      return const AuthResult.failure(
        'Password must be at least 6 characters.',
      );
    }
    _hasGuestData = false;
    _guestCount = 0;
    isAdopted = true;
    return AuthResult.success(userId: 'uid_${email.hashCode}', email: email);
  }

  @override
  Future<AuthResult> upgradeWithGoogle() async {
    _hasGuestData = false;
    _guestCount = 0;
    isAdopted = true;
    return const AuthResult.success(
      userId: 'google_user_001',
      email: 'google_user@haqly.app',
    );
  }

  @override
  Future<void> adoptGuestData({
    required String newUserId,
    String guestUserId = AuthState.localSentinel,
  }) async {
    _hasGuestData = false;
    _guestCount = 0;
    isAdopted = true;
  }

  @override
  Future<AuthResult> resolveExistingAccount({
    required String email,
    required String password,
    required ExistingAccountChoice choice,
    String guestUserId = AuthState.localSentinel,
  }) async {
    if (password.length < 6) {
      return const AuthResult.failure('Invalid email or password.');
    }
    final userId = 'uid_${email.hashCode}';
    switch (choice) {
      case ExistingAccountChoice.keepCloud:
        _hasGuestData = false;
        _guestCount = 0;
        isDiscarded = true;
        isHydratedFromCloud = true;
        break;
      case ExistingAccountChoice.replaceWithDevice:
        _hasGuestData = false;
        _guestCount = 0;
        isAdopted = true;
        break;
    }
    return AuthResult.success(userId: userId, email: email);
  }
}
