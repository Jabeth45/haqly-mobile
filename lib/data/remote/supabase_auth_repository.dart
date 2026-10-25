import 'package:haqly_mobile/data/repositories/auth_repository.dart';
import 'package:haqly_mobile/domain/models/auth_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Supabase implementation of [AuthRepository].
/// Follows docs/ARCHITECTURE.md Section 6, docs/SECURITY.md Section 3, and PRD FR-A1 / FR-A5.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({this.clientOverride});

  final supa.SupabaseClient? clientOverride;

  supa.SupabaseClient get client =>
      clientOverride ?? supa.Supabase.instance.client;

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  String? get currentUserEmail => client.auth.currentUser?.email;

  @override
  bool get isAuthenticated => client.auth.currentSession != null;

  @override
  Future<AuthResult> signInAnonymously() async {
    try {
      final res = await client.auth.signInAnonymously();
      final user = res.user;

      if (user == null) {
        return const AuthResult.failure('Unable to sign in anonymously.');
      }

      return AuthResult.success(userId: user.id, email: user.email);
    } on supa.AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (_) {
      return const AuthResult.failure('Network or authentication error.');
    }
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final user = res.user;
      final session = res.session;

      if (user == null) {
        return const AuthResult.failure('Unable to complete registration.');
      }

      return AuthResult.success(
        userId: user.id,
        email: user.email,
        requiresVerification: session == null,
      );
    } on supa.AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (_) {
      return const AuthResult.failure('Network or authentication error.');
    }
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = res.user;

      if (user == null) {
        return const AuthResult.failure('Invalid email or password.');
      }

      return AuthResult.success(userId: user.id, email: user.email);
    } on supa.AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (_) {
      return const AuthResult.failure('Network or authentication error.');
    }
  }

  @override
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      final res = await client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: supa.OtpType.signup,
      );
      final user = res.user;

      if (user == null) {
        return const AuthResult.failure(
          'Invalid or expired verification code.',
        );
      }

      return AuthResult.success(userId: user.id, email: user.email);
    } on supa.AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (_) {
      return const AuthResult.failure('Network or verification error.');
    }
  }

  @override
  Future<AuthResult> resendOtp({required String email}) async {
    try {
      await client.auth.resend(email: email.trim(), type: supa.OtpType.signup);
      return const AuthResult.success();
    } on supa.AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (_) {
      return const AuthResult.failure('Unable to resend verification code.');
    }
  }

  @override
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      return const AuthResult.success();
    } on supa.AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (_) {
      return const AuthResult.failure('Unable to send password reset code.');
    }
  }

  @override
  Future<AuthResult> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final verifyRes = await client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: supa.OtpType.recovery,
      );

      if (verifyRes.user == null) {
        return const AuthResult.failure('Invalid or expired reset code.');
      }

      await client.auth.updateUser(supa.UserAttributes(password: newPassword));

      return const AuthResult.success();
    } on supa.AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (_) {
      return const AuthResult.failure('Unable to update password.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (_) {
      // Ignored on clean logout
    }
  }

  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials') ||
        lower.contains('invalid_grant')) {
      return 'Invalid email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email address before signing in.';
    }
    if (lower.contains('token has expired') || lower.contains('expired')) {
      return 'Verification code has expired.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many attempts. Please try again in a few minutes.';
    }
    return message;
  }
}
