import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:haqly_mobile/data/db/tables.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Expenses,
    CheckItems,
    LedgerEntries,
    Budgets,
    Contacts,
    UserCategories,
    Outbox,
    SyncMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// In-memory database instance for testing.
  factory AppDatabase.inMemory({QueryExecutor? executor}) {
    return AppDatabase(executor ?? NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Schema upgrades from v1 onwards will be placed here.
    },
  );

  /// Atomically deletes all records across all tables in a single transaction.
  /// Follows PRD FR-A7, SECURITY S-08, and Scenario M14 (local wipe on delete-account).
  Future<void> wipeAllData() {
    return transaction(() async {
      await delete(expenses).go();
      await delete(checkItems).go();
      await delete(ledgerEntries).go();
      await delete(budgets).go();
      await delete(contacts).go();
      await delete(userCategories).go();
      await delete(outbox).go();
      await delete(syncMeta).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'haqly.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
