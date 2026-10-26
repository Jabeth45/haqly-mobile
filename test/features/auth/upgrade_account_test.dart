import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haqly_mobile/core/l10n/generated/app_localizations.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/remote/fake_remote_gateway.dart';
import 'package:haqly_mobile/data/repositories/account_repository.dart';
import 'package:haqly_mobile/data/repositories/auth_repository.dart';
import 'package:haqly_mobile/data/repositories/session_repository.dart';
import 'package:haqly_mobile/data/sync/adopt.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';
import 'package:haqly_mobile/data/sync/pull.dart';
import 'package:haqly_mobile/domain/models/account_choice.dart';
import 'package:haqly_mobile/features/auth/presentation/upgrade_screen.dart';
import 'package:haqly_mobile/features/auth/providers/auth_providers.dart';

void main() {
  group('TASK-036: Account Upgrade & Conflict Resolution (M3 & M4)', () {
    late AppDatabase db;
    late OutboxQueue outbox;
    late AdoptionService adoptionService;
    late FakeAuthRepository fakeAuth;
    late FakeRemoteGateway fakeRemote;
    late PullService pullService;
    late SessionRepository sessionRepo;
    late AccountRepository accountRepo;

    final testClock = FixedClock(DateTime.utc(2026, 10, 26, 12, 0, 0));

    setUp(() {
      db = AppDatabase.inMemory();
      outbox = OutboxQueue(db, clock: testClock);
      adoptionService = AdoptionService(db, outbox, clock: testClock);
      fakeAuth = FakeAuthRepository()..requireOtpForSignUp = false;
      fakeRemote = FakeRemoteGateway();
      pullService = PullService(
        db: db,
        outboxQueue: outbox,
        remoteGateway: fakeRemote,
      );
      sessionRepo = LocalSessionRepository.inMemory();
      accountRepo = AccountRepositoryImpl(
        adoptionService: adoptionService,
        authRepository: fakeAuth,
        sessionRepository: sessionRepo,
        pullService: pullService,
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedLocalGuestData() async {
      final nowUtc = DateTime.utc(2026, 10, 26, 10, 0, 0).toIso8601String();
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-local-1',
              name: 'Lunch',
              amountMinor: 25000,
              localDate: '2026-10-26',
              createdAt: nowUtc,
              clientUpdatedAt: nowUtc,
            ),
          );
      await db
          .into(db.checkItems)
          .insert(
            CheckItemsCompanion.insert(
              id: 'chk-local-1',
              name: 'Headphones',
              priceMinor: 150000,
              uses: 10.0,
              verdict: 'worth_it',
              regretLevel: 1,
              localDate: '2026-10-26',
              createdAt: nowUtc,
              clientUpdatedAt: nowUtc,
            ),
          );
      await db
          .into(db.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: 'led-local-1',
              person: 'Abebe',
              amountMinor: 50000,
              type: 'lent',
              localDate: '2026-10-26',
              createdAt: nowUtc,
              clientUpdatedAt: nowUtc,
            ),
          );
    }

    test('Scenario M3: guest with local data upgrades with new email - data adopted and outbox queued', () async {
      await seedLocalGuestData();
      expect(await accountRepo.countGuestData(), 3);

      fakeAuth.requireOtpForSignUp = false;

      final result = await accountRepo.upgradeWithEmail(
        email: 'brandnew@haqly.app',
        password: 'password123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.emailAlreadyInUse, isFalse);
      expect(result.userId, isNotNull);

      // Verify guest data is adopted to the new user ID
      final expenses = await db.select(db.expenses).get();
      expect(expenses.length, 1);
      expect(expenses.first.userId, result.userId);

      final checks = await db.select(db.checkItems).get();
      expect(checks.length, 1);
      expect(checks.first.userId, result.userId);

      final ledgers = await db.select(db.ledgerEntries).get();
      expect(ledgers.length, 1);
      expect(ledgers.first.userId, result.userId);

      // Verify outbox queued for cloud sync
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 3);

      // Session updated
      final restored = await sessionRepo.restoreSession();
      expect(restored.isAuthenticated, isTrue);
      expect(restored.userId, result.userId);
    });

    test(
      'Scenario M4: upgrade with an already registered email detects conflict',
      () async {
        await seedLocalGuestData();

        // Pre-register existing account
        await fakeAuth.signUpWithEmail(
          email: 'existing@haqly.app',
          password: 'password123',
        );

        // Attempt upgrade with same email
        final result = await accountRepo.upgradeWithEmail(
          email: 'existing@haqly.app',
          password: 'password123',
        );

        expect(result.isSuccess, isFalse);
        expect(result.emailAlreadyInUse, isTrue);
        // Local guest data is untouched
        expect(await accountRepo.countGuestData(), 3);
      },
    );

    test('Scenario M4 (Keep Cloud): user chooses keep cloud data - guest data discarded and cloud data pulled', () async {
      await seedLocalGuestData();

      // Existing cloud account has 1 expense in cloud
      await fakeAuth.signUpWithEmail(
        email: 'existing@haqly.app',
        password: 'password123',
      );
      final existingUserId = 'uid_${'existing@haqly.app'.hashCode}';

      await fakeRemote.upsert('expenses', {
        'id': 'exp-cloud-99',
        'user_id': existingUserId,
        'name': 'Cloud Hotel',
        'amount': 120.00,
        'category': 'Meals',
        'type': 'expense',
        'local_date': '2026-10-20',
        'created_at': '2026-10-20T10:00:00.000Z',
        'client_updated_at': '2026-10-20T10:00:00.000Z',
        'deleted_at': null,
      });

      final resolveRes = await accountRepo.resolveExistingAccount(
        email: 'existing@haqly.app',
        password: 'password123',
        choice: ExistingAccountChoice.keepCloud,
      );

      expect(resolveRes.isSuccess, isTrue);
      expect(resolveRes.userId, existingUserId);

      // Local guest records must be discarded (0 guest data)
      expect(await accountRepo.countGuestData(), 0);

      // Cloud records are hydrated into local database
      final expenses = await db.select(db.expenses).get();
      expect(expenses.length, 1);
      expect(expenses.first.id, 'exp-cloud-99');
      expect(expenses.first.name, 'Cloud Hotel');

      // Local guest records did not leak to cloud or remain in DB
      final checks = await db.select(db.checkItems).get();
      expect(checks.isEmpty, isTrue);
    });

    test('Scenario M4 (Replace with Device Data): user chooses replace with device data - guest data adopted to account', () async {
      await seedLocalGuestData();

      await fakeAuth.signUpWithEmail(
        email: 'existing@haqly.app',
        password: 'password123',
      );
      final existingUserId = 'uid_${'existing@haqly.app'.hashCode}';

      final resolveRes = await accountRepo.resolveExistingAccount(
        email: 'existing@haqly.app',
        password: 'password123',
        choice: ExistingAccountChoice.replaceWithDevice,
      );

      expect(resolveRes.isSuccess, isTrue);
      expect(resolveRes.userId, existingUserId);

      // All local guest records adopted to existing account
      final expenses = await db.select(db.expenses).get();
      expect(expenses.length, 1);
      expect(expenses.first.userId, existingUserId);

      final checks = await db.select(db.checkItems).get();
      expect(checks.length, 1);
      expect(checks.first.userId, existingUserId);

      final ledgers = await db.select(db.ledgerEntries).get();
      expect(ledgers.length, 1);
      expect(ledgers.first.userId, existingUserId);

      // Outbox entries enqueued for sync to cloud
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 3);
    });
  });

  group('UpgradeScreen Widget Tests', () {
    late FakeAccountRepository fakeAccountRepo;

    setUp(() {
      fakeAccountRepo = FakeAccountRepository(
        initialHasGuestData: true,
        initialCountGuestData: 3,
        existingRegisteredEmails: {'conflict@haqly.app'},
      );
    });

    Widget createTestApp({String initialLocation = '/upgrade'}) {
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const Scaffold(body: Text('Home Screen')),
          ),
          GoRoute(
            path: '/upgrade',
            builder: (context, state) => const UpgradeScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) =>
                const Scaffold(body: Text('Login Screen')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(fakeAccountRepo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
    }

    testWidgets('renders upgrade screen elements and fields', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Upgrade Account'), findsWidgets);
      expect(find.byKey(const Key('upgrade_email_field')), findsOneWidget);
      expect(find.byKey(const Key('upgrade_password_field')), findsOneWidget);
      expect(find.byKey(const Key('upgrade_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('upgrade_to_login_button')), findsOneWidget);
    });

    testWidgets('upgrading with new email triggers upgrade action', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('upgrade_email_field')),
        'new@haqly.app',
      );
      await tester.enterText(
        find.byKey(const Key('upgrade_password_field')),
        'securePassword1',
      );

      await tester.tap(find.byKey(const Key('upgrade_submit_button')));
      await tester.pumpAndSettle();

      expect(fakeAccountRepo.isAdopted, isTrue);
    });

    testWidgets(
      'upgrading with existing email opens conflict choice dialog and resolves Keep Cloud',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('upgrade_email_field')),
          'conflict@haqly.app',
        );
        await tester.enterText(
          find.byKey(const Key('upgrade_password_field')),
          'securePassword1',
        );

        await tester.tap(find.byKey(const Key('upgrade_submit_button')));
        await tester.pumpAndSettle();

        // Bottom sheet with M4 choices is shown
        expect(find.text('Account Already Exists'), findsOneWidget);
        expect(find.byKey(const Key('keep_cloud_option')), findsOneWidget);
        expect(find.byKey(const Key('replace_device_option')), findsOneWidget);

        // Confirm with Keep Cloud (default)
        await tester.tap(
          find.byKey(const Key('confirm_conflict_choice_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeAccountRepo.isDiscarded, isTrue);
        expect(fakeAccountRepo.isHydratedFromCloud, isTrue);
      },
    );

    testWidgets(
      'upgrading with existing email can choose Replace with Device Data',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('upgrade_email_field')),
          'conflict@haqly.app',
        );
        await tester.enterText(
          find.byKey(const Key('upgrade_password_field')),
          'securePassword1',
        );

        await tester.tap(find.byKey(const Key('upgrade_submit_button')));
        await tester.pumpAndSettle();

        // Tap Replace with Device option
        await tester.tap(find.byKey(const Key('replace_device_option')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('confirm_conflict_choice_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeAccountRepo.isAdopted, isTrue);
        expect(fakeAccountRepo.isDiscarded, isFalse);
      },
    );
  });
}
