import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart'
    hide CheckItem, Expense, LedgerEntry;
import 'package:haqly_mobile/data/repositories/check_repository.dart';
import 'package:haqly_mobile/data/repositories/expense_repository.dart';
import 'package:haqly_mobile/data/repositories/ledger_repository.dart';
import 'package:haqly_mobile/data/repositories/session_repository.dart';
import 'package:haqly_mobile/domain/check_calculator.dart';
import 'package:haqly_mobile/domain/models/auth_state.dart';
import 'package:haqly_mobile/domain/models/check_item.dart';
import 'package:haqly_mobile/domain/models/expense.dart';
import 'package:haqly_mobile/domain/models/ledger_entry.dart';
import 'package:haqly_mobile/domain/models/ledger_type.dart';
import 'package:haqly_mobile/domain/models/transaction_type.dart';
import 'package:haqly_mobile/domain/money.dart';
import 'package:haqly_mobile/features/auth/providers/auth_providers.dart';
import 'package:haqly_mobile/main.dart';

void main() {
  group('TASK-031: Auth Boot & Guest Sentinel Navigation', () {
    testWidgets(
      'fresh install routes to WelcomeScreen and Continue as Guest navigates to Home',
      (tester) async {
        final sessionRepo = LocalSessionRepository.inMemory(isGuest: false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionRepositoryProvider.overrideWithValue(sessionRepo),
            ],
            child: const HaqlyApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Fresh install should show WelcomeScreen
        expect(find.text('Haqly'), findsOneWidget);
        expect(
          find.byKey(const Key('continue_as_guest_button')),
          findsOneWidget,
        );
        expect(find.text('Home Screen'), findsNothing);

        // Tap 'Continue as Guest'
        await tester.tap(find.byKey(const Key('continue_as_guest_button')));
        await tester.pumpAndSettle();

        // Should now be on Home Screen with persistent bottom navigation
        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byKey(const Key('continue_as_guest_button')), findsNothing);

        // Verify session was persisted
        final state = await sessionRepo.restoreSession();
        expect(state.isGuest, isTrue);
        expect(state.userId, AuthState.localSentinel);
      },
    );

    testWidgets(
      'restored guest session cold-boots directly to Home with no flash of auth (FR-A6)',
      (tester) async {
        // Pre-seed storage with guest session
        final sessionRepo = LocalSessionRepository.inMemory(isGuest: true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionRepositoryProvider.overrideWithValue(sessionRepo),
            ],
            child: const HaqlyApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Cold start routes straight to Home
        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byKey(const Key('continue_as_guest_button')), findsNothing);
      },
    );

    test('Scenario M1 (Data Layer): local guest logs expense, income, check, and ledger offline', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);

      final fixedClock = FixedClock(DateTime.utc(2026, 10, 25, 12, 0, 0));
      final expenseRepo = DriftExpenseRepository(db, clock: fixedClock);
      final checkRepo = DriftCheckRepository(db, clock: fixedClock);
      final ledgerRepo = DriftLedgerRepository(db, clock: fixedClock);

      const guestUserId = AuthState.localSentinel;

      // 1. Log an offline expense
      final expense = Expense(
        id: 'exp_001',
        userId: guestUserId,
        name: 'Macchiato',
        amount: const Money.fromMinorUnits(3500),
        category: 'Meals',
        type: TransactionType.expense,
        localDate: '2026-10-25',
        createdAt: DateTime.utc(2026, 10, 25, 8, 30, 0),
        clientUpdatedAt: DateTime.utc(2026, 10, 25, 8, 30, 0),
      );
      await expenseRepo.save(expense);

      // 2. Log an offline income
      final income = Expense(
        id: 'inc_001',
        userId: guestUserId,
        name: 'Allowance',
        amount: const Money.fromMinorUnits(500000),
        category: 'Allowance',
        type: TransactionType.income,
        localDate: '2026-10-25',
        createdAt: DateTime.utc(2026, 10, 25, 9, 0, 0),
        clientUpdatedAt: DateTime.utc(2026, 10, 25, 9, 0, 0),
      );
      await expenseRepo.save(income);

      // 3. Log a value check
      final checkItem = CheckItem(
        id: 'chk_001',
        userId: guestUserId,
        name: 'Sneakers',
        price: const Money.fromMinorUnits(450000),
        uses: 50.0,
        costPerUseMinor: 9000,
        verdict: Verdict.worth,
        regretLevel: 1,
        localDate: '2026-10-25',
        createdAt: DateTime.utc(2026, 10, 25, 10, 0, 0),
        clientUpdatedAt: DateTime.utc(2026, 10, 25, 10, 0, 0),
      );
      await checkRepo.save(checkItem);

      // 4. Log a ledger entry (lent money)
      final ledgerEntry = LedgerEntry(
        id: 'led_001',
        userId: guestUserId,
        person: 'Abebe',
        amount: const Money.fromMinorUnits(20000, currency: 'ETB'),
        currency: 'ETB',
        type: LedgerType.lent,
        settled: false,
        localDate: '2026-10-25',
        createdAt: DateTime.utc(2026, 10, 25, 11, 0, 0),
        clientUpdatedAt: DateTime.utc(2026, 10, 25, 11, 0, 0),
      );
      await ledgerRepo.save(ledgerEntry);

      // Verify all rows exist locally with user_id = LOCAL
      final savedExpenses = await expenseRepo.watchAll().first;
      expect(savedExpenses.length, 2);
      expect(savedExpenses.every((e) => e.userId == guestUserId), isTrue);

      final savedChecks = await checkRepo.watchAll().first;
      expect(savedChecks.length, 1);
      expect(savedChecks.first.userId, guestUserId);

      final savedLedger = await ledgerRepo.watchAll().first;
      expect(savedLedger.length, 1);
      expect(savedLedger.first.userId, guestUserId);

      // Verify outbox queue captured all 4 entries atomically
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 4);
      expect(outboxEntries.map((o) => o.recordTable).toSet(), {
        'expenses',
        'check_items',
        'ledger_entries',
      });
    });
  });
}
