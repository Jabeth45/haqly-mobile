/// Pure Dart authentication result wrapper.
/// Prevents leaking Supabase types to domain, provider, and UI layers.
/// Follows docs/RULES.md Rule 1 and Rule 4.
class AuthResult {
  const AuthResult.success({
    this.userId,
    this.email,
    this.requiresVerification = false,
  }) : errorMessage = null;

  const AuthResult.failure(this.errorMessage)
    : userId = null,
      email = null,
      requiresVerification = false;

  /// User unique identifier if session was created.
  final String? userId;

  /// User email address if authenticated.
  final String? email;

  /// True if registration succeeded and an OTP verification code was sent.
  final bool requiresVerification;

  /// Human-readable, non-enumerating error message on failure.
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}
