import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/remote/fake_remote_gateway.dart';
import 'package:haqly_mobile/data/repositories/account_repository.dart';
import 'package:haqly_mobile/data/repositories/auth_repository.dart';
import 'package:haqly_mobile/data/repositories/session_repository.dart';
import 'package:haqly_mobile/data/sync/adopt.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';
import 'package:haqly_mobile/data/sync/pull.dart';
import 'package:haqly_mobile/features/auth/presentation/upgrade_screen.dart';
import 'package:haqly_mobile/features/auth/providers/auth_providers.dart';
import 'package:haqly_mobile/main.dart';

void main() {
  group('TASK-037: Google Sign-In & Account Linking (FR-A2)', () {
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

    testWidgets('sign in with Google from Welcome screen navigates to Home', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // On WelcomeScreen
      expect(find.byKey(const Key('welcome_google_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('welcome_google_button')));
      await tester.pumpAndSettle();

      // Navigated to Home
      expect(find.text('Home Screen'), findsOneWidget);
      expect(authRepo.isAuthenticated, isTrue);
      expect(authRepo.currentUserEmail, 'google_user@haqly.app');

      final session = await sessionRepo.restoreSession();
      expect(session.isAuthenticated, isTrue);
      expect(session.isGuest, isFalse);
    });

    testWidgets('sign in with Google from Login screen navigates to Home', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Welcome -> Sign In
      await tester.tap(find.byKey(const Key('welcome_signin_button')));
      await tester.pumpAndSettle();

      // On LoginScreen
      expect(find.byKey(const Key('google_signin_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('google_signin_button')));
      await tester.pumpAndSettle();

      // Navigated to Home
      expect(find.text('Home Screen'), findsOneWidget);
      expect(authRepo.isAuthenticated, isTrue);
    });

    testWidgets('sign up with Google from Register screen navigates to Home', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Welcome -> Sign In -> Register
      await tester.tap(find.byKey(const Key('welcome_signin_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('goto_register_button')));
      await tester.pumpAndSettle();

      // On RegisterScreen
      expect(find.byKey(const Key('google_signup_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('google_signup_button')));
      await tester.pumpAndSettle();

      // Navigated to Home
      expect(find.text('Home Screen'), findsOneWidget);
      expect(authRepo.isAuthenticated, isTrue);
    });

    testWidgets('Google sign-in displays error message on failure', (
      tester,
    ) async {
      authRepo.failGoogleSignIn = true;

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Welcome -> Sign In
      await tester.tap(find.byKey(const Key('welcome_signin_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('google_signin_button')));
      await tester.pumpAndSettle();

      // Error message visible on screen
      expect(find.textContaining('cancelled or failed'), findsOneWidget);
      expect(authRepo.isAuthenticated, isFalse);
    });

    testWidgets(
      'Google upgrade preserves local guest records and queues outbox pointers',
      (tester) async {
        final db = AppDatabase.inMemory();
        final testClock = FixedClock(DateTime.utc(2026, 10, 26, 12, 0, 0));
        final outbox = OutboxQueue(db, clock: testClock);
        final adoptionService = AdoptionService(db, outbox, clock: testClock);
        final fakeRemote = FakeRemoteGateway();
        final pullService = PullService(
          db: db,
          outboxQueue: outbox,
          remoteGateway: fakeRemote,
        );
        final accountRepo = AccountRepositoryImpl(
          adoptionService: adoptionService,
          authRepository: authRepo,
          sessionRepository: sessionRepo,
          pullService: pullService,
        );

        // Seed 1 local guest expense
        final nowUtc = DateTime.utc(2026, 10, 26, 10, 0, 0).toIso8601String();
        await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-local-1',
                name: 'Coffee',
                amountMinor: 6000,
                localDate: '2026-10-26',
                createdAt: nowUtc,
                clientUpdatedAt: nowUtc,
              ),
            );

        final router = GoRouter(
          initialLocation: '/upgrade',
          routes: [
            GoRoute(
              path: '/upgrade',
              builder: (context, state) => const UpgradeScreen(),
            ),
            GoRoute(
              path: '/home',
              builder: (context, state) =>
                  const Scaffold(body: Text('Home Screen')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(authRepo),
              sessionRepositoryProvider.overrideWithValue(sessionRepo),
              accountRepositoryProvider.overrideWithValue(accountRepo),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('google_upgrade_button')), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('google_upgrade_button')),
        );
        await tester.tap(find.byKey(const Key('google_upgrade_button')));
        await tester.pumpAndSettle();

        // Guest row was adopted to the Google user
        final expenses = await db.select(db.expenses).get();
        expect(expenses.single.userId, 'google_user_001');

        // Outbox pointer was enqueued
        final outboxEntries = await outbox.getReadyEntries();
        expect(outboxEntries.length, 1);
        expect(outboxEntries.single.rowId, 'exp-local-1');

        await db.close();
      },
    );
  });
}
