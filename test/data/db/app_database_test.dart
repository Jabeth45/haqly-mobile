import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('TASK-020: Drift AppDatabase Schema v1', () {
    test('database opens and schema version is 1', () async {
      expect(db.schemaVersion, equals(1));

      final versionResult = await db
          .customSelect('PRAGMA user_version;')
          .getSingle();
      final userVersion = versionResult.data['user_version'] as int;
      expect(userVersion, equals(1));
    });

    test('all tables are created in sqlite_master', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';",
          )
          .get();

      final tableNames = rows.map((r) => r.data['name'] as String).toSet();

      expect(
        tableNames,
        containsAll([
          'expenses',
          'check_items',
          'ledger_entries',
          'budgets',
          'contacts',
          'user_categories',
          'outbox',
          'sync_meta',
        ]),
      );
    });

    test('all required indexes are created in sqlite_master', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%';",
          )
          .get();

      final indexNames = rows.map((r) => r.data['name'] as String).toSet();

      expect(
        indexNames,
        containsAll([
          'expenses_user_local_date_idx',
          'expenses_user_category_idx',
          'expenses_user_type_created_idx',
          'check_items_user_local_date_idx',
          'ledger_entries_user_local_date_idx',
          'ledger_entries_user_type_created_idx',
          'ledger_entries_user_settled_idx',
          'contacts_user_name_idx',
          'user_categories_user_kind_idx',
          'outbox_table_row_idx',
        ]),
      );
    });

    test('Expenses table CRUD and default values', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      const expenseId = 'exp-uuid-1';

      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: expenseId,
              name: 'Lunch',
              amountMinor: 15000,
              localDate: '2026-10-22',
              createdAt: now,
              clientUpdatedAt: now,
            ),
          );

      final row = await (db.select(
        db.expenses,
      )..where((t) => t.id.equals(expenseId))).getSingle();

      expect(row.id, equals(expenseId));
      expect(row.userId, equals('LOCAL'));
      expect(row.name, equals('Lunch'));
      expect(row.amountMinor, equals(15000));
      expect(row.category, equals('Other'));
      expect(row.type, equals('expense'));
      expect(row.localDate, equals('2026-10-22'));
      expect(row.deletedAt, isNull);

      // Soft delete test
      final deletedTimestamp = DateTime.now().toUtc().toIso8601String();
      await (db.update(
        db.expenses,
      )..where((t) => t.id.equals(expenseId))).write(
        ExpensesCompanion(
          deletedAt: Value(deletedTimestamp),
          clientUpdatedAt: Value(deletedTimestamp),
        ),
      );

      final updatedRow = await (db.select(
        db.expenses,
      )..where((t) => t.id.equals(expenseId))).getSingle();
      expect(updatedRow.deletedAt, equals(deletedTimestamp));

      final activeRows = await (db.select(
        db.expenses,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(activeRows, isEmpty);
    });

    test('CheckItems table CRUD', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      const checkId = 'check-uuid-1';

      await db
          .into(db.checkItems)
          .insert(
            CheckItemsCompanion.insert(
              id: checkId,
              name: 'Espresso Machine',
              priceMinor: 1500000,
              uses: 365.0,
              costPerUseMinor: const Value(4110),
              verdict: 'worth',
              regretLevel: 1,
              localDate: '2026-10-22',
              createdAt: now,
              clientUpdatedAt: now,
            ),
          );

      final item = await (db.select(
        db.checkItems,
      )..where((t) => t.id.equals(checkId))).getSingle();

      expect(item.id, equals(checkId));
      expect(item.userId, equals('LOCAL'));
      expect(item.name, equals('Espresso Machine'));
      expect(item.priceMinor, equals(1500000));
      expect(item.uses, equals(365.0));
      expect(item.costPerUseMinor, equals(4110));
      expect(item.verdict, equals('worth'));
      expect(item.regretLevel, equals(1));
    });

    test('LedgerEntries table CRUD and settled toggle', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      const ledgerId = 'ledger-uuid-1';

      await db
          .into(db.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              id: ledgerId,
              person: 'Abebe',
              amountMinor: 50000,
              type: 'lent',
              localDate: '2026-10-22',
              createdAt: now,
              clientUpdatedAt: now,
              note: const Value('Taxi split'),
            ),
          );

      var entry = await (db.select(
        db.ledgerEntries,
      )..where((t) => t.id.equals(ledgerId))).getSingle();

      expect(entry.person, equals('Abebe'));
      expect(entry.currency, equals('ETB'));
      expect(entry.type, equals('lent'));
      expect(entry.settled, isFalse);
      expect(entry.note, equals('Taxi split'));

      // Settle the debt
      await (db.update(db.ledgerEntries)..where((t) => t.id.equals(ledgerId)))
          .write(const LedgerEntriesCompanion(settled: Value(true)));

      entry = await (db.select(
        db.ledgerEntries,
      )..where((t) => t.id.equals(ledgerId))).getSingle();
      expect(entry.settled, isTrue);
    });

    test('Budgets table unique user constraint', () async {
      final now = DateTime.now().toUtc().toIso8601String();

      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'budget-1',
              userId: 'LOCAL',
              monthlyMinor: const Value(500000),
              weeklyMinor: const Value(125000),
              updatedAt: now,
              clientUpdatedAt: now,
            ),
          );

      final budget = await (db.select(
        db.budgets,
      )..where((t) => t.userId.equals('LOCAL'))).getSingle();
      expect(budget.monthlyMinor, equals(500000));
      expect(budget.weeklyMinor, equals(125000));

      // Attempt duplicate user_id insertion should fail with uniqueness constraint
      expect(
        () => db
            .into(db.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: 'budget-2',
                userId: 'LOCAL',
                updatedAt: now,
                clientUpdatedAt: now,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('Contacts table CRUD', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      const contactId = 'contact-uuid-1';

      await db
          .into(db.contacts)
          .insert(
            ContactsCompanion.insert(
              id: contactId,
              name: 'Chala',
              phone: const Value('+251911223344'),
              note: const Value('Classmate'),
              createdAt: now,
              clientUpdatedAt: now,
            ),
          );

      final contact = await (db.select(
        db.contacts,
      )..where((t) => t.id.equals(contactId))).getSingle();
      expect(contact.name, equals('Chala'));
      expect(contact.phone, equals('+251911223344'));
      expect(contact.note, equals('Classmate'));
    });

    test('UserCategories table CRUD', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      const catId = 'cat-uuid-1';

      await db
          .into(db.userCategories)
          .insert(
            UserCategoriesCompanion.insert(
              id: catId,
              name: 'Gym',
              kind: 'expense',
              createdAt: now,
              clientUpdatedAt: now,
            ),
          );

      final category = await (db.select(
        db.userCategories,
      )..where((t) => t.id.equals(catId))).getSingle();
      expect(category.name, equals('Gym'));
      expect(category.kind, equals('expense'));
    });

    test('Outbox queue FIFO and attempts tracking', () async {
      final now = DateTime.now().toUtc().toIso8601String();

      final id1 = await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              recordTable: 'expenses',
              rowId: 'exp-1',
              createdAt: now,
            ),
          );

      final id2 = await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              recordTable: 'expenses',
              rowId: 'exp-2',
              createdAt: now,
            ),
          );

      expect(id2, greaterThan(id1));

      final items = await (db.select(
        db.outbox,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(items.length, equals(2));
      expect(items[0].rowId, equals('exp-1'));
      expect(items[0].recordTable, equals('expenses'));
      expect(items[0].attempts, equals(0));
      expect(items[1].rowId, equals('exp-2'));
    });

    test('SyncMeta cursor management', () async {
      await db
          .into(db.syncMeta)
          .insert(
            SyncMetaCompanion.insert(
              recordTable: 'expenses',
              cursorUpdatedAt: const Value('2026-10-22T12:00:00Z'),
              cursorId: const Value('exp-100'),
            ),
          );

      final meta = await (db.select(
        db.syncMeta,
      )..where((t) => t.recordTable.equals('expenses'))).getSingle();
      expect(meta.recordTable, equals('expenses'));
      expect(meta.cursorUpdatedAt, equals('2026-10-22T12:00:00Z'));
      expect(meta.cursorId, equals('exp-100'));
    });
  });
}
