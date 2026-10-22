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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'haqly.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
