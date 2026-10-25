import 'package:haqly_mobile/domain/models/auth_result.dart';

/// Contract for remote authentication operations.
/// Follows docs/ARCHITECTURE.md Section 6, docs/SECURITY.md S-04, and PRD FR-A1.
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

  /// Verifies email verification OTP token.
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String token,
  });

  /// Resends an OTP verification token.
  Future<AuthResult> resendOtp({required String email});

  /// Signs out of the active account.
  Future<void> signOut();

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

  String? _currentUserId;
  String? _currentUserEmail;
  bool _isAuthenticated = false;

  bool requireOtpForSignUp = true;
  String fixedOtp = '123456';

  @override
  String? get currentUserId => _currentUserId;

  @override
  String? get currentUserEmail => _currentUserEmail;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (password.length < 6) {
      return const AuthResult.failure(
        'Password must be at least 6 characters.',
      );
    }

    _registeredUsers[email.toLowerCase()] = password;

    if (requireOtpForSignUp) {
      _pendingOtps[email.toLowerCase()] = fixedOtp;
      return AuthResult.success(email: email, requiresVerification: true);
    }

    _currentUserId = 'uid_${email.hashCode}';
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
      // Return success to prevent enumeration
      return const AuthResult.success();
    }
    _pendingOtps[normalized] = fixedOtp;
    return const AuthResult.success();
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
    _currentUserEmail = null;
    _isAuthenticated = false;
  }
}
