import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/data/repositories/auth_repository.dart';

void main() {
  group('TASK-033: AuthRepository (Fake & Business Logic)', () {
    late FakeAuthRepository authRepo;

    setUp(() {
      authRepo = FakeAuthRepository();
    });

    test('signUpWithEmail requires password length >= 6', () async {
      final result = await authRepo.signUpWithEmail(
        email: 'user@haqly.app',
        password: '123',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('at least 6 characters'));
    });

    test('signUpWithEmail triggers verification requirement', () async {
      final result = await authRepo.signUpWithEmail(
        email: 'user@haqly.app',
        password: 'password123',
      );
      expect(result.isSuccess, isTrue);
      expect(result.requiresVerification, isTrue);
      expect(authRepo.isAuthenticated, isFalse);
    });

    test('signInWithEmail fails before email is verified', () async {
      await authRepo.signUpWithEmail(
        email: 'user@haqly.app',
        password: 'password123',
      );

      final signInResult = await authRepo.signInWithEmail(
        email: 'user@haqly.app',
        password: 'password123',
      );
      expect(signInResult.isSuccess, isFalse);
      expect(signInResult.errorMessage, contains('verify your email'));
    });

    test('verifyEmailOtp authenticates account on correct token', () async {
      await authRepo.signUpWithEmail(
        email: 'user@haqly.app',
        password: 'password123',
      );

      // Attempt wrong OTP
      final wrongRes = await authRepo.verifyEmailOtp(
        email: 'user@haqly.app',
        token: '000000',
      );
      expect(wrongRes.isSuccess, isFalse);
      expect(wrongRes.errorMessage, contains('Invalid or expired'));
      expect(authRepo.isAuthenticated, isFalse);

      // Verify with correct OTP
      final verifyRes = await authRepo.verifyEmailOtp(
        email: 'user@haqly.app',
        token: '123456',
      );
      expect(verifyRes.isSuccess, isTrue);
      expect(authRepo.isAuthenticated, isTrue);
      expect(authRepo.currentUserEmail, 'user@haqly.app');
      expect(authRepo.currentUserId, isNotNull);

      // Subsequent sign-in succeeds
      await authRepo.signOut();
      expect(authRepo.isAuthenticated, isFalse);

      final loginRes = await authRepo.signInWithEmail(
        email: 'user@haqly.app',
        password: 'password123',
      );
      expect(loginRes.isSuccess, isTrue);
      expect(authRepo.isAuthenticated, isTrue);
    });

    test(
      'signInWithEmail gives generic error for unregistered or wrong password',
      () async {
        final res = await authRepo.signInWithEmail(
          email: 'nonexistent@haqly.app',
          password: 'password123',
        );
        expect(res.isSuccess, isFalse);
        expect(res.errorMessage, 'Invalid email or password.');
      },
    );
  });

  group('TASK-034: Password Recovery Flow (FR-A5)', () {
    late FakeAuthRepository authRepo;

    setUp(() async {
      authRepo = FakeAuthRepository();
      // Register and verify a user
      await authRepo.signUpWithEmail(
        email: 'recover@haqly.app',
        password: 'oldPassword123',
      );
      await authRepo.verifyEmailOtp(
        email: 'recover@haqly.app',
        token: '123456',
      );
      await authRepo.signOut();
    });

    test(
      'sendPasswordResetEmail succeeds without exposing user existence',
      () async {
        final res = await authRepo.sendPasswordResetEmail(
          email: 'recover@haqly.app',
        );
        expect(res.isSuccess, isTrue);

        final unregRes = await authRepo.sendPasswordResetEmail(
          email: 'unknown@haqly.app',
        );
        expect(unregRes.isSuccess, isTrue);
      },
    );

    test(
      'resetPasswordWithOtp requires valid token and min 6 char password',
      () async {
        await authRepo.sendPasswordResetEmail(email: 'recover@haqly.app');

        // Invalid token
        final badToken = await authRepo.resetPasswordWithOtp(
          email: 'recover@haqly.app',
          token: '999999',
          newPassword: 'newPassword456',
        );
        expect(badToken.isSuccess, isFalse);
        expect(badToken.errorMessage, contains('Invalid or expired'));

        // Short password
        final shortPass = await authRepo.resetPasswordWithOtp(
          email: 'recover@haqly.app',
          token: '123456',
          newPassword: '123',
        );
        expect(shortPass.isSuccess, isFalse);
        expect(shortPass.errorMessage, contains('at least 6 characters'));

        // Valid reset
        final success = await authRepo.resetPasswordWithOtp(
          email: 'recover@haqly.app',
          token: '123456',
          newPassword: 'newPassword456',
        );
        expect(success.isSuccess, isTrue);

        // Old password no longer works
        final oldLogin = await authRepo.signInWithEmail(
          email: 'recover@haqly.app',
          password: 'oldPassword123',
        );
        expect(oldLogin.isSuccess, isFalse);

        // New password works
        final newLogin = await authRepo.signInWithEmail(
          email: 'recover@haqly.app',
          password: 'newPassword456',
        );
        expect(newLogin.isSuccess, isTrue);
        expect(authRepo.isAuthenticated, isTrue);
      },
    );
  });

  group('TASK-037: Google Authentication (FR-A2)', () {
    late FakeAuthRepository authRepo;

    setUp(() {
      authRepo = FakeAuthRepository();
    });

    test('signInWithGoogle successfully authenticates', () async {
      final res = await authRepo.signInWithGoogle();
      expect(res.isSuccess, isTrue);
      expect(res.userId, 'google_user_001');
      expect(res.email, 'google_user@haqly.app');
      expect(authRepo.isAuthenticated, isTrue);
    });

    test('signInWithGoogle handles cancellation or error', () async {
      authRepo.failGoogleSignIn = true;
      final res = await authRepo.signInWithGoogle();
      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('cancelled or failed'));
      expect(authRepo.isAuthenticated, isFalse);
    });

    test('linkGoogle successfully links to account', () async {
      final res = await authRepo.linkGoogle();
      expect(res.isSuccess, isTrue);
      expect(res.userId, 'google_user_001');
      expect(res.email, 'google_user@haqly.app');
      expect(authRepo.isAuthenticated, isTrue);
    });

    test('linkGoogle detects account collision', () async {
      authRepo.googleEmailInUse = true;
      final res = await authRepo.linkGoogle();
      expect(res.isSuccess, isFalse);
      expect(res.emailAlreadyInUse, isTrue);
    });
  });
}
