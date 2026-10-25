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
}
