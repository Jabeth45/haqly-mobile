import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/remote/fake_remote_gateway.dart';
import 'package:haqly_mobile/data/repositories/account_repository.dart';
import 'package:haqly_mobile/data/repositories/auth_repository.dart';
import 'package:haqly_mobile/data/repositories/session_repository.dart';
import 'package:haqly_mobile/data/sync/adopt.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';
import 'package:haqly_mobile/data/sync/pull.dart';
import 'package:haqly_mobile/domain/models/auth_state.dart';
import 'package:haqly_mobile/features/auth/providers/auth_providers.dart';

void main() {
  group(
    'TASK-038: End-to-End Account Deletion Flow (FR-A7, S-08, Scenario M14)',
    () {
      late AppDatabase db;
      late OutboxQueue outbox;
      late AdoptionService adoptionService;
      late FakeAuthRepository fakeAuth;
      late FakeRemoteGateway fakeRemote;
      late PullService pullService;
      late LocalSessionRepository sessionRepo;
      late AccountRepository accountRepo;
      late ProviderContainer container;

      final testClock = FixedClock(DateTime.utc(2026, 10, 27, 12, 0, 0));

      setUp(() async {
        db = AppDatabase.inMemory();
        outbox = OutboxQueue(db, clock: testClock);
        adoptionService = AdoptionService(db, outbox, clock: testClock);
        fakeAuth = FakeAuthRepository(
          initialUserId: 'user-to-delete',
          initialEmail: 'user@haqly.app',
        );
        fakeRemote = FakeRemoteGateway();
        pullService = PullService(
          db: db,
          outboxQueue: outbox,
          remoteGateway: fakeRemote,
        );
        sessionRepo = LocalSessionRepository.inMemory();
        await sessionRepo.setAuthenticatedUser(
          userId: 'user-to-delete',
          email: 'user@haqly.app',
        );

        accountRepo = AccountRepositoryImpl(
          adoptionService: adoptionService,
          authRepository: fakeAuth,
          sessionRepository: sessionRepo,
          pullService: pullService,
          db: db,
        );

        container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            sessionRepositoryProvider.overrideWithValue(sessionRepo),
            accountRepositoryProvider.overrideWithValue(accountRepo),
          ],
        );
      });

      tearDown(() async {
        container.dispose();
        await db.close();
      });

      Future<void> seedUserFinancialData() async {
        const nowUtc = '2026-10-27T10:00:00.000Z';
        await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-del-1',
                name: 'Groceries',
                amountMinor: 45000,
                localDate: '2026-10-27',
                createdAt: nowUtc,
                clientUpdatedAt: nowUtc,
              ),
            );

        await db
            .into(db.checkItems)
            .insert(
              CheckItemsCompanion.insert(
                id: 'chk-del-1',
                name: 'Watch',
                priceMinor: 200000,
                uses: 15.0,
                verdict: 'worth_it',
                regretLevel: 1,
                localDate: '2026-10-27',
                createdAt: nowUtc,
                clientUpdatedAt: nowUtc,
              ),
            );

        await db
            .into(db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                id: 'led-del-1',
                person: 'Dawit',
                amountMinor: 35000,
                type: 'lent',
                localDate: '2026-10-27',
                createdAt: nowUtc,
                clientUpdatedAt: nowUtc,
              ),
            );

        await db
            .into(db.outbox)
            .insert(
              OutboxCompanion.insert(
                recordTable: 'expenses',
                rowId: 'exp-del-1',
                createdAt: nowUtc,
              ),
            );
      }

      test('successful deleteAccount wipes cloud auth, local SQLite data, and clears session', () async {
        await seedUserFinancialData();

        // Verify data is present prior to deletion
        expect(await db.select(db.expenses).get(), isNotEmpty);
        expect(await db.select(db.checkItems).get(), isNotEmpty);
        expect(await db.select(db.ledgerEntries).get(), isNotEmpty);
        expect(await db.select(db.outbox).get(), isNotEmpty);
        expect((await sessionRepo.restoreSession()).isAuthenticated, isTrue);

        // Trigger delete account through AuthNotifier
        final result = await container
            .read(authStateProvider.notifier)
            .deleteAccount();

        expect(result.isSuccess, isTrue);

        // 1. Remote user signed out and cleared
        expect(fakeAuth.isAuthenticated, isFalse);
        expect(fakeAuth.currentUserId, isNull);

        // 2. Local SQLite database completely wiped
        expect(await db.select(db.expenses).get(), isEmpty);
        expect(await db.select(db.checkItems).get(), isEmpty);
        expect(await db.select(db.ledgerEntries).get(), isEmpty);
        expect(await db.select(db.outbox).get(), isEmpty);

        // 3. Session cleared
        final restoredSession = await sessionRepo.restoreSession();
        expect(restoredSession.isAuthenticated, isFalse);
        expect(restoredSession.isGuest, isFalse);

        // 4. Notifier state transitioned to unauthenticated
        expect(
          container.read(authStateProvider),
          const AuthState.unauthenticated(),
        );
      });

      test(
        'failed remote deleteAccount aborts and preserves local data',
        () async {
          await seedUserFinancialData();
          fakeAuth.failAccountDeletion = true;

          final result = await container
              .read(authStateProvider.notifier)
              .deleteAccount();

          expect(result.isSuccess, isFalse);
          expect(result.errorMessage, contains('Unable to delete account'));

          // Data is preserved because remote deletion failed
          expect(await db.select(db.expenses).get(), isNotEmpty);
          expect(await db.select(db.checkItems).get(), isNotEmpty);
          expect(await db.select(db.ledgerEntries).get(), isNotEmpty);
          expect(await db.select(db.outbox).get(), isNotEmpty);

          // Session remains active
          expect((await sessionRepo.restoreSession()).isAuthenticated, isTrue);
        },
      );
    },
  );
}
