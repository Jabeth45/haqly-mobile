import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/data/repositories/auth_repository.dart';
import 'package:haqly_mobile/data/repositories/session_repository.dart';
import 'package:haqly_mobile/features/auth/providers/auth_providers.dart';
import 'package:haqly_mobile/main.dart';

void main() {
  group('TASK-034: Forgot Password Flow Widget Test (FR-A5)', () {
    late FakeAuthRepository authRepo;
    late LocalSessionRepository sessionRepo;

    setUp(() async {
      authRepo = FakeAuthRepository();
      sessionRepo = LocalSessionRepository.inMemory(isGuest: false);

      // Pre-register and verify a user
      await authRepo.signUpWithEmail(
        email: 'user@haqly.app',
        password: 'initialPassword123',
      );
      await authRepo.verifyEmailOtp(email: 'user@haqly.app', token: '123456');
      await authRepo.signOut();
    });

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          sessionRepositoryProvider.overrideWithValue(sessionRepo),
        ],
        child: const HaqlyApp(),
      );
    }

    testWidgets(
      'end-to-end recovery: login -> forgot password -> submit email -> enter OTP + new pass -> sign in -> home',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Welcome -> Sign In
        await tester.tap(find.byKey(const Key('welcome_signin_button')));
        await tester.pumpAndSettle();

        // On Login -> Tap 'Forgot Password?'
        expect(
          find.byKey(const Key('login_forgot_password_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('login_forgot_password_button')));
        await tester.pumpAndSettle();

        // Step 1: Request reset code
        expect(find.byKey(const Key('forgot_email_field')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('forgot_email_field')),
          'user@haqly.app',
        );
        await tester.tap(find.byKey(const Key('send_reset_code_button')));
        await tester.pumpAndSettle();

        // Step 2: Enter code and new password
        expect(find.byKey(const Key('reset_otp_field')), findsOneWidget);
        expect(find.byKey(const Key('new_password_field')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('reset_otp_field')),
          '123456',
        );
        await tester.enterText(
          find.byKey(const Key('new_password_field')),
          'brandNewPassword789',
        );
        await tester.tap(find.byKey(const Key('submit_new_password_button')));
        await tester.pumpAndSettle();

        // Success view displayed
        expect(
          find.byKey(const Key('reset_success_signin_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('reset_success_signin_button')));
        await tester.pumpAndSettle();

        // Back on Login screen -> Sign in with new password
        expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('login_email_field')),
          'user@haqly.app',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'brandNewPassword789',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Arrives on Home screen
        expect(find.text('Home Screen'), findsOneWidget);
        expect(authRepo.isAuthenticated, isTrue);
      },
    );
  });
}
