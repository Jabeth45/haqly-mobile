import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/data/db/app_database.dart';

void main() {
  group('TASK-020: Schema v1 Migration Harness', () {
    test(
      'database executes onCreate and passes PRAGMA integrity_check',
      () async {
        final db = AppDatabase.inMemory();

        // Ensure database is initialized and schema version is 1
        expect(db.schemaVersion, equals(1));

        final integrityResult = await db
            .customSelect('PRAGMA integrity_check;')
            .getSingle();
        expect(integrityResult.data['integrity_check'], equals('ok'));

        // Validate all expected tables exist
        final tables = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';",
            )
            .get();
        final tableNames = tables.map((r) => r.data['name'] as String).toSet();

        expect(
          tableNames,
          equals({
            'expenses',
            'check_items',
            'ledger_entries',
            'budgets',
            'contacts',
            'user_categories',
            'outbox',
            'sync_meta',
          }),
        );

        // Validate columns of expenses table
        final expenseColumns = await db
            .customSelect('PRAGMA table_info(expenses);')
            .get();
        final colNames = expenseColumns
            .map((r) => r.data['name'] as String)
            .toList();
        expect(
          colNames,
          containsAll([
            'id',
            'user_id',
            'name',
            'amount_minor',
            'category',
            'type',
            'local_date',
            'created_at',
            'client_updated_at',
            'deleted_at',
          ]),
        );

        await db.close();
      },
    );
  });
}
