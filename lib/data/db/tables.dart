import 'package:drift/drift.dart';

/// Local expenses and income table.
/// Corresponds to Supabase `public.expenses`.
@TableIndex(
  name: 'expenses_user_local_date_idx',
  columns: {#userId, #localDate},
)
@TableIndex(name: 'expenses_user_category_idx', columns: {#userId, #category})
@TableIndex(
  name: 'expenses_user_type_created_idx',
  columns: {#userId, #type, #createdAt},
)
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('LOCAL'))();
  TextColumn get name => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  TextColumn get type => text().withDefault(const Constant('expense'))();
  TextColumn get localDate => text()();
  TextColumn get createdAt => text()();
  TextColumn get clientUpdatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Value check items table.
/// Corresponds to Supabase `public.check_items`.
@TableIndex(
  name: 'check_items_user_local_date_idx',
  columns: {#userId, #localDate},
)
class CheckItems extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('LOCAL'))();
  TextColumn get name => text()();
  IntColumn get priceMinor => integer()();
  RealColumn get uses => real()();
  IntColumn get costPerUseMinor => integer().nullable()();
  TextColumn get verdict => text()();
  IntColumn get regretLevel => integer()();
  TextColumn get localDate => text()();
  TextColumn get createdAt => text()();
  TextColumn get clientUpdatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ledger entries table (lent and borrowed money).
/// Corresponds to Supabase `public.ledger_entries`.
@TableIndex(
  name: 'ledger_entries_user_local_date_idx',
  columns: {#userId, #localDate},
)
@TableIndex(
  name: 'ledger_entries_user_type_created_idx',
  columns: {#userId, #type, #createdAt},
)
@TableIndex(
  name: 'ledger_entries_user_settled_idx',
  columns: {#userId, #settled},
)
class LedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('LOCAL'))();
  TextColumn get person => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('ETB'))();
  TextColumn get type => text()();
  TextColumn get note => text().nullable()();
  BoolColumn get settled => boolean().withDefault(const Constant(false))();
  TextColumn get localDate => text()();
  TextColumn get createdAt => text()();
  TextColumn get clientUpdatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Budget configuration per user.
/// Corresponds to Supabase `public.budgets`.
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().unique()();
  IntColumn get monthlyMinor => integer().nullable()();
  IntColumn get weeklyMinor => integer().nullable()();
  TextColumn get updatedAt => text()();
  TextColumn get clientUpdatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Contacts list for ledger autocomplete and tracking.
/// Corresponds to Supabase `public.contacts`.
@TableIndex(name: 'contacts_user_name_idx', columns: {#userId, #name})
class Contacts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('LOCAL'))();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get clientUpdatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Custom user-defined expense and income categories.
/// Corresponds to Supabase `public.user_categories`.
@TableIndex(name: 'user_categories_user_kind_idx', columns: {#userId, #kind})
class UserCategories extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('LOCAL'))();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get createdAt => text()();
  TextColumn get clientUpdatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Outbox table storing pointers to modified rows awaiting background sync.
@TableIndex(name: 'outbox_table_row_idx', columns: {#recordTable, #rowId})
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordTable => text().named('table_name')();
  TextColumn get rowId => text()();
  TextColumn get createdAt => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

/// Metadata table keeping pull sync cursors per table.
class SyncMeta extends Table {
  TextColumn get recordTable => text().named('table_name')();
  TextColumn get cursorUpdatedAt => text().nullable()();
  TextColumn get cursorId => text().nullable()();

  @override
  Set<Column> get primaryKey => {recordTable};
}
