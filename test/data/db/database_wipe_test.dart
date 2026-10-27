import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/data/db/app_database.dart';

void main() {
  group('TASK-038: AppDatabase.wipeAllData (FR-A7, M14)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.inMemory();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'wipeAllData empties all 8 tables atomically in a single transaction',
      () async {
        const nowUtc = '2026-10-27T12:00:00.000Z';

        // Seed records across tables
        await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-1',
                name: 'Dinner',
                amountMinor: 30000,
                localDate: '2026-10-27',
                createdAt: nowUtc,
                clientUpdatedAt: nowUtc,
              ),
            );

        await db
            .into(db.checkItems)
            .insert(
              CheckItemsCompanion.insert(
                id: 'chk-1',
                name: 'Bag',
                priceMinor: 50000,
                uses: 5.0,
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
                id: 'led-1',
                person: 'Sara',
                amountMinor: 20000,
                type: 'lent',
                localDate: '2026-10-27',
                createdAt: nowUtc,
                clientUpdatedAt: nowUtc,
              ),
            );

        await db
            .into(db.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: 'bgt-1',
                userId: 'u1',
                updatedAt: nowUtc,
                clientUpdatedAt: nowUtc,
                monthlyMinor: const Value(100000),
              ),
            );

        await db
            .into(db.contacts)
            .insert(
              ContactsCompanion.insert(
                id: 'cnt-1',
                name: 'Sara',
                createdAt: nowUtc,
                clientUpdatedAt: nowUtc,
              ),
            );

        await db
            .into(db.userCategories)
            .insert(
              UserCategoriesCompanion.insert(
                id: 'cat-1',
                name: 'Books',
                kind: 'expense',
                createdAt: nowUtc,
                clientUpdatedAt: nowUtc,
              ),
            );

        await db
            .into(db.outbox)
            .insert(
              OutboxCompanion.insert(
                recordTable: 'expenses',
                rowId: 'exp-1',
                createdAt: nowUtc,
              ),
            );

        await db
            .into(db.syncMeta)
            .insert(
              SyncMetaCompanion.insert(
                recordTable: 'expenses',
                cursorUpdatedAt: const Value(nowUtc),
                cursorId: const Value('exp-1'),
              ),
            );

        // Verify records are present
        expect((await db.select(db.expenses).get()).length, 1);
        expect((await db.select(db.checkItems).get()).length, 1);
        expect((await db.select(db.ledgerEntries).get()).length, 1);
        expect((await db.select(db.budgets).get()).length, 1);
        expect((await db.select(db.contacts).get()).length, 1);
        expect((await db.select(db.userCategories).get()).length, 1);
        expect((await db.select(db.outbox).get()).length, 1);
        expect((await db.select(db.syncMeta).get()).length, 1);

        // Execute wipe
        await db.wipeAllData();

        // Verify all tables are completely empty
        expect(await db.select(db.expenses).get(), isEmpty);
        expect(await db.select(db.checkItems).get(), isEmpty);
        expect(await db.select(db.ledgerEntries).get(), isEmpty);
        expect(await db.select(db.budgets).get(), isEmpty);
        expect(await db.select(db.contacts).get(), isEmpty);
        expect(await db.select(db.userCategories).get(), isEmpty);
        expect(await db.select(db.outbox).get(), isEmpty);
        expect(await db.select(db.syncMeta).get(), isEmpty);
      },
    );
  });
}
