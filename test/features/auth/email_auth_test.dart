import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/data/repositories/auth_repository.dart';
import 'package:haqly_mobile/data/repositories/session_repository.dart';
import 'package:haqly_mobile/features/auth/providers/auth_providers.dart';
import 'package:haqly_mobile/main.dart';

void main() {
  group('TASK-033: Email Auth & OTP Verify Widget Flows (FR-A1)', () {
    late FakeAuthRepository authRepo;
    late LocalSessionRepository sessionRepo;

    setUp(() {
      authRepo = FakeAuthRepository();
      sessionRepo = LocalSessionRepository.inMemory(isGuest: false);
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
      'full flow: welcome -> sign in -> register -> verify OTP -> home',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Starts at WelcomeScreen
        expect(find.byKey(const Key('welcome_signin_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('welcome_signin_button')));
        await tester.pumpAndSettle();

        // On LoginScreen -> Switch to Register
        expect(find.byKey(const Key('goto_register_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('goto_register_button')));
        await tester.pumpAndSettle();

        // On RegisterScreen -> Fill form
        expect(find.byKey(const Key('register_email_field')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('register_email_field')),
          'newuser@haqly.app',
        );
        await tester.enterText(
          find.byKey(const Key('register_password_field')),
          'securePass123',
        );
        await tester.tap(find.byKey(const Key('register_submit_button')));
        await tester.pumpAndSettle();

        // Should transition to OtpVerifyScreen
        expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
        expect(find.text('newuser@haqly.app'), findsOneWidget);

        // Enter OTP code
        await tester.enterText(
          find.byKey(const Key('otp_code_field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('verify_otp_submit_button')));
        await tester.pumpAndSettle();

        // Should now be authenticated on HomeScreen
        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(authRepo.isAuthenticated, isTrue);

        // Verify persistent session was saved
        final session = await sessionRepo.restoreSession();
        expect(session.isAuthenticated, isTrue);
        expect(session.isGuest, isFalse);
      },
    );

    testWidgets('direct sign in with correct credentials navigates to home', (
      tester,
    ) async {
      // Pre-register and verify account in fake repo
      await authRepo.signUpWithEmail(
        email: 'verified@haqly.app',
        password: 'password123',
      );
      await authRepo.verifyEmailOtp(
        email: 'verified@haqly.app',
        token: '123456',
      );
      await authRepo.signOut();

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Welcome -> Sign In
      await tester.tap(find.byKey(const Key('welcome_signin_button')));
      await tester.pumpAndSettle();

      // Enter credentials
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'verified@haqly.app',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Arrives on Home
      expect(find.text('Home Screen'), findsOneWidget);
      expect(authRepo.isAuthenticated, isTrue);
    });

    testWidgets('sign in with wrong password shows inline error', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('welcome_signin_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'wrong@haqly.app',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'wrongPassword',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Generic error message shown inline
      expect(find.text('Invalid email or password.'), findsOneWidget);
      expect(authRepo.isAuthenticated, isFalse);
    });
  });
}
