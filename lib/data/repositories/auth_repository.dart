import 'package:haqly_mobile/domain/models/auth_result.dart';

/// Contract for remote authentication operations.
/// Follows docs/ARCHITECTURE.md Section 6, docs/SECURITY.md S-04, and PRD FR-A1 / FR-A5.
abstract class AuthRepository {
  /// Signs up a new account using email and password.
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Signs in an existing account using email and password.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  /// Converts/links the active guest session to a registered account with email and password.
  /// If [email] already exists on another account, returns [AuthResult.emailAlreadyInUse].
  Future<AuthResult> linkEmail({
    required String email,
    required String password,
  });

  /// Signs in anonymously to obtain a stable cloud user identifier.
  Future<AuthResult> signInAnonymously();

  /// Verifies email verification OTP token.
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String token,
  });

  /// Resends an OTP verification token.
  Future<AuthResult> resendOtp({required String email});

  /// Sends a password recovery OTP to the given email address.
  Future<AuthResult> sendPasswordResetEmail({required String email});

  /// Verifies password recovery OTP and updates the account password.
  Future<AuthResult> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  });

  /// Signs out of the active account.
  Future<void> signOut();

  /// Permanently deletes the authenticated user account and associated cloud data.
  /// Follows PRD FR-A7, SECURITY S-08, and Scenario M14.
  Future<AuthResult> deleteAccount();

  /// Signs in using Google authentication.
  Future<AuthResult> signInWithGoogle({String? redirectTo});

  /// Links Google authentication to the active account.
  Future<AuthResult> linkGoogle({String? redirectTo});

  /// Current authenticated user identifier or null.
  String? get currentUserId;

  /// Current authenticated user email or null.
  String? get currentUserEmail;

  /// Whether a remote session currently exists.
  bool get isAuthenticated;
}

/// In-memory test double for headless testing.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? initialUserId, String? initialEmail}) {
    if (initialUserId != null) {
      _currentUserId = initialUserId;
      _currentUserEmail = initialEmail ?? 'user@haqly.app';
      _isAuthenticated = true;
    }
  }

  final Map<String, String> _registeredUsers = {};
  final Map<String, String> _pendingOtps = {};
  final Map<String, String> _pendingRecoveryOtps = {};

  String? _currentUserId;
  String? _currentUserEmail;
  bool _isAuthenticated = false;

  bool requireOtpForSignUp = true;
  String fixedOtp = '123456';

  String fakeGoogleUserId = 'google_user_001';
  String fakeGoogleEmail = 'google_user@haqly.app';
  bool failGoogleSignIn = false;
  bool googleEmailInUse = false;
  bool failAccountDeletion = false;

  @override
  String? get currentUserId => _currentUserId;

  @override
  String? get currentUserEmail => _currentUserEmail;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<AuthResult> signInWithGoogle({String? redirectTo}) async {
    if (failGoogleSignIn) {
      return const AuthResult.failure(
        'Google sign-in was cancelled or failed.',
      );
    }
    _currentUserId = fakeGoogleUserId;
    _currentUserEmail = fakeGoogleEmail;
    _isAuthenticated = true;
    return AuthResult.success(userId: _currentUserId, email: _currentUserEmail);
  }

  @override
  Future<AuthResult> linkGoogle({String? redirectTo}) async {
    if (failGoogleSignIn) {
      return const AuthResult.failure('Google account link failed.');
    }
    if (googleEmailInUse) {
      return AuthResult.emailAlreadyInUse(email: fakeGoogleEmail);
    }
    _currentUserId ??= fakeGoogleUserId;
    _currentUserEmail = fakeGoogleEmail;
    _isAuthenticated = true;
    return AuthResult.success(userId: _currentUserId, email: _currentUserEmail);
  }

  @override
  Future<AuthResult> signInAnonymously() async {
    _currentUserId = 'anon_${DateTime.now().millisecondsSinceEpoch}';
    _currentUserEmail = null;
    _isAuthenticated = true;

    return AuthResult.success(userId: _currentUserId);
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = email.toLowerCase();
    if (_registeredUsers.containsKey(normalized)) {
      return AuthResult.emailAlreadyInUse(email: email);
    }

    if (password.length < 6) {
      return const AuthResult.failure(
        'Password must be at least 6 characters.',
      );
    }

    _registeredUsers[normalized] = password;

    if (requireOtpForSignUp) {
      _pendingOtps[normalized] = fixedOtp;
      return AuthResult.success(email: email, requiresVerification: true);
    }

    _currentUserId = 'uid_${normalized.hashCode}';
    _currentUserEmail = email;
    _isAuthenticated = true;

    return AuthResult.success(userId: _currentUserId, email: email);
  }

  @override
  Future<AuthResult> linkEmail({
    required String email,
    required String password,
  }) async {
    final normalized = email.toLowerCase();
    if (_registeredUsers.containsKey(normalized)) {
      return AuthResult.emailAlreadyInUse(email: email);
    }

    if (password.length < 6) {
      return const AuthResult.failure(
        'Password must be at least 6 characters.',
      );
    }

    _registeredUsers[normalized] = password;

    if (requireOtpForSignUp) {
      _pendingOtps[normalized] = fixedOtp;
      return AuthResult.success(email: email, requiresVerification: true);
    }

    _currentUserId ??= 'uid_${normalized.hashCode}';
    _currentUserEmail = email;
    _isAuthenticated = true;

    return AuthResult.success(userId: _currentUserId, email: email);
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = email.toLowerCase();
    if (!_registeredUsers.containsKey(normalized) ||
        _registeredUsers[normalized] != password) {
      return const AuthResult.failure('Invalid email or password.');
    }

    if (_pendingOtps.containsKey(normalized)) {
      return const AuthResult.failure(
        'Please verify your email address before signing in.',
      );
    }

    _currentUserId = 'uid_${normalized.hashCode}';
    _currentUserEmail = email;
    _isAuthenticated = true;

    return AuthResult.success(userId: _currentUserId, email: email);
  }

  @override
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final normalized = email.toLowerCase();
    final expected = _pendingOtps[normalized];

    if (expected == null || expected != token.trim()) {
      return const AuthResult.failure('Invalid or expired verification code.');
    }

    _pendingOtps.remove(normalized);
    _currentUserId = 'uid_${normalized.hashCode}';
    _currentUserEmail = email;
    _isAuthenticated = true;

    return AuthResult.success(userId: _currentUserId, email: email);
  }

  @override
  Future<AuthResult> resendOtp({required String email}) async {
    final normalized = email.toLowerCase();
    if (!_registeredUsers.containsKey(normalized)) {
      return const AuthResult.success();
    }
    _pendingOtps[normalized] = fixedOtp;
    return const AuthResult.success();
  }

  @override
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    final normalized = email.toLowerCase();
    if (_registeredUsers.containsKey(normalized)) {
      _pendingRecoveryOtps[normalized] = fixedOtp;
    }
    return const AuthResult.success();
  }

  @override
  Future<AuthResult> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final normalized = email.toLowerCase();
    final expected = _pendingRecoveryOtps[normalized];

    if (expected == null || expected != token.trim()) {
      return const AuthResult.failure('Invalid or expired reset code.');
    }

    if (newPassword.length < 6) {
      return const AuthResult.failure(
        'Password must be at least 6 characters.',
      );
    }

    _registeredUsers[normalized] = newPassword;
    _pendingRecoveryOtps.remove(normalized);

    return const AuthResult.success();
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
    _currentUserEmail = null;
    _isAuthenticated = false;
  }

  @override
  Future<AuthResult> deleteAccount() async {
    if (failAccountDeletion) {
      return const AuthResult.failure(
        'Unable to delete account. Please try again.',
      );
    }
    if (_currentUserEmail != null) {
      _registeredUsers.remove(_currentUserEmail!.toLowerCase());
    }
    _currentUserId = null;
    _currentUserEmail = null;
    _isAuthenticated = false;
    return const AuthResult.success();
  }
}
