import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/repositories/auth_repository.dart';
import 'package:haqly_mobile/data/sync/adopt.dart';
import 'package:haqly_mobile/data/sync/outbox.dart';
import 'package:haqly_mobile/domain/models/auth_state.dart';

void main() {
  group('TASK-035: AdoptionService & Idempotency (M3)', () {
    late AppDatabase db;
    late OutboxQueue outbox;
    late AdoptionService adoptionService;
    final fixedClock = FixedClock(DateTime.utc(2026, 10, 25, 12, 0, 0));

    setUp(() {
      db = AppDatabase.inMemory();
      outbox = OutboxQueue(db, clock: fixedClock);
      adoptionService = AdoptionService(db, outbox, clock: fixedClock);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedLocalGuestData() async {
      final nowUtc = DateTime.utc(2026, 10, 25, 10, 0, 0).toIso8601String();

      // 1. Expense
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-1',
              name: 'Injera',
              amountMinor: 15000,
              localDate: '2026-10-25',
              createdAt: nowUtc,
              clientUpdatedAt: nowUtc,
            ),
          );

      // 2. Check Item
      await db
          .into(db.checkItems)
          .insert(
            CheckItemsCompanion.insert(
              id: 'chk-1',
              name: 'Coat',
              priceMinor: 200000,
              uses: 20.0,
              verdict: 'worth_it',
              regretLevel: 1,
              localDate: '2026-10-25',
              createdAt: nowUtc,
              clientUpdatedAt: nowUtc,
            ),
          );

      // 3. Ledger Entry
      await db
          .into(db.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: 'led-1',
              person: 'Sara',
              amountMinor: 50000,
              currency: const Value('ETB'),
              type: 'lent',
              settled: const Value(false),
              localDate: '2026-10-25',
              createdAt: nowUtc,
              clientUpdatedAt: nowUtc,
            ),
          );

      // 4. Budget
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'bud-1',
              userId: 'LOCAL',
              monthlyMinor: const Value(1000000),
              updatedAt: nowUtc,
              clientUpdatedAt: nowUtc,
            ),
          );

      // 5. Contact
      await db
          .into(db.contacts)
          .insert(
            ContactsCompanion.insert(
              id: 'con-1',
              name: 'Abebe',
              createdAt: nowUtc,
              clientUpdatedAt: nowUtc,
            ),
          );

      // 6. User Category
      await db
          .into(db.userCategories)
          .insert(
            UserCategoriesCompanion.insert(
              id: 'cat-1',
              name: 'Coffee Ceremony',
              kind: 'expense',
              createdAt: nowUtc,
              clientUpdatedAt: nowUtc,
            ),
          );
    }

    test('adopts all 6 tables from LOCAL to cloud user and enqueues outbox pointers', () async {
      await seedLocalGuestData();

      const newUid = 'cloud_user_999';
      final result = await adoptionService.adopt(newUserId: newUid);

      expect(result.totalAdopted, 6);
      expect(result.adoptedExpenses, 1);
      expect(result.adoptedChecks, 1);
      expect(result.adoptedLedger, 1);
      expect(result.adoptedBudgets, 1);
      expect(result.adoptedContacts, 1);
      expect(result.adoptedCategories, 1);
      expect(result.hasChanges, isTrue);

      // Verify all tables have new user_id
      final exp = await db.select(db.expenses).getSingle();
      expect(exp.userId, newUid);

      final chk = await db.select(db.checkItems).getSingle();
      expect(chk.userId, newUid);

      final led = await db.select(db.ledgerEntries).getSingle();
      expect(led.userId, newUid);

      final bud = await db.select(db.budgets).getSingle();
      expect(bud.userId, newUid);

      final con = await db.select(db.contacts).getSingle();
      expect(con.userId, newUid);

      final cat = await db.select(db.userCategories).getSingle();
      expect(cat.userId, newUid);

      // Verify outbox entries created for all 6 adopted records
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 6);
      expect(outboxEntries.map((e) => e.recordTable).toSet(), {
        'expenses',
        'check_items',
        'ledger_entries',
        'budgets',
        'contacts',
        'user_categories',
      });
    });

    test(
      'idempotency: adopt twice = no change and no duplicate queue entries',
      () async {
        await seedLocalGuestData();

        const newUid = 'cloud_user_999';

        // First run: adopts rows
        final firstRun = await adoptionService.adopt(newUserId: newUid);
        expect(firstRun.totalAdopted, 6);
        expect(firstRun.hasChanges, isTrue);

        final initialOutboxCount = (await db.select(db.outbox).get()).length;
        expect(initialOutboxCount, 6);

        // Second run: no LOCAL rows remain
        final secondRun = await adoptionService.adopt(newUserId: newUid);
        expect(secondRun.totalAdopted, 0);
        expect(secondRun.hasChanges, isFalse);

        // Verify outbox is completely unchanged
        final afterSecondOutboxCount =
            (await db.select(db.outbox).get()).length;
        expect(afterSecondOutboxCount, initialOutboxCount);
      },
    );

    test(
      'adopt with identical from and to user ids makes no changes',
      () async {
        await seedLocalGuestData();

        final result = await adoptionService.adopt(
          newUserId: AuthState.localSentinel,
          fromUserId: AuthState.localSentinel,
        );
        expect(result.totalAdopted, 0);
        expect(result.hasChanges, isFalse);

        final outboxEntries = await db.select(db.outbox).get();
        expect(outboxEntries.isEmpty, isTrue);
      },
    );

    test('Scenario M3 first half: guest logs data, signs in anonymously, and adopts data', () async {
      await seedLocalGuestData();

      final fakeAuth = FakeAuthRepository();
      final authRes = await fakeAuth.signInAnonymously();
      expect(authRes.isSuccess, isTrue);
      expect(authRes.userId, isNotNull);

      // Run adoption callback
      final adoptRes = await adoptionService.adopt(newUserId: authRes.userId!);
      expect(adoptRes.totalAdopted, 6);

      // Verify all rows now belong to anon UID
      final expenses = await db.select(db.expenses).get();
      expect(expenses.every((e) => e.userId == authRes.userId), isTrue);
    });

    test(
      'hasGuestData and countGuestData accurately reflect active records',
      () async {
        expect(await adoptionService.hasGuestData(), isFalse);
        expect(await adoptionService.countGuestData(), 0);

        await seedLocalGuestData();

        expect(await adoptionService.hasGuestData(), isTrue);
        expect(await adoptionService.countGuestData(), 6);
      },
    );

    test('discardGuestData removes all guest records and outbox entries atomically', () async {
      await seedLocalGuestData();
      expect(await adoptionService.hasGuestData(), isTrue);

      await adoptionService.discardGuestData();

      expect(await adoptionService.hasGuestData(), isFalse);
      expect(await adoptionService.countGuestData(), 0);

      final expenses = await db.select(db.expenses).get();
      final checks = await db.select(db.checkItems).get();
      final ledgers = await db.select(db.ledgerEntries).get();
      final budgets = await db.select(db.budgets).get();
      final contacts = await db.select(db.contacts).get();
      final categories = await db.select(db.userCategories).get();
      final outboxEntries = await db.select(db.outbox).get();

      expect(expenses.isEmpty, isTrue);
      expect(checks.isEmpty, isTrue);
      expect(ledgers.isEmpty, isTrue);
      expect(budgets.isEmpty, isTrue);
      expect(contacts.isEmpty, isTrue);
      expect(categories.isEmpty, isTrue);
      expect(outboxEntries.isEmpty, isTrue);
    });
  });
}
