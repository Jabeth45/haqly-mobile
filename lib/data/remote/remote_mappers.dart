import 'package:drift/drift.dart';
import 'package:haqly_mobile/data/db/app_database.dart';

/// Converts Drift database rows into Supabase remote JSON payloads.
/// Converts integer minor units into decimal values for numeric(14,2) columns.
/// Follows docs/backend/supabase_schema.sql and docs/ARCHITECTURE.md Section 5.
abstract final class RemoteMappers {
  /// Converts integer minor units to decimal double (e.g. 1250 minor units -> 12.50).
  static double minorToDecimal(int minorUnits) {
    return minorUnits / 100.0;
  }

  /// Converts decimal double to integer minor units (e.g. 12.50 -> 1250).
  static int decimalToMinor(num decimal) {
    return (decimal * 100).round();
  }

  /// Maps local [Expense] row to remote payload.
  static Map<String, dynamic> expenseToRemote(Expense row) {
    return {
      'id': row.id,
      'user_id': row.userId,
      'name': row.name,
      'amount': minorToDecimal(row.amountMinor),
      'category': row.category,
      'type': row.type,
      'local_date': row.localDate,
      'created_at': row.createdAt,
      'client_updated_at': row.clientUpdatedAt,
      'deleted_at': row.deletedAt,
    };
  }

  /// Maps local [CheckItem] row to remote payload.
  static Map<String, dynamic> checkItemToRemote(CheckItem row) {
    return {
      'id': row.id,
      'user_id': row.userId,
      'name': row.name,
      'price': minorToDecimal(row.priceMinor),
      'uses': row.uses,
      'cost_per_use': row.costPerUseMinor != null
          ? minorToDecimal(row.costPerUseMinor!)
          : (row.uses > 0 ? (row.priceMinor / 100.0) / row.uses : 0.0),
      'verdict': row.verdict,
      'regret_level': row.regretLevel,
      'local_date': row.localDate,
      'created_at': row.createdAt,
      'client_updated_at': row.clientUpdatedAt,
      'deleted_at': row.deletedAt,
    };
  }

  /// Maps local [LedgerEntry] row to remote payload.
  static Map<String, dynamic> ledgerEntryToRemote(LedgerEntry row) {
    return {
      'id': row.id,
      'user_id': row.userId,
      'person': row.person,
      'amount': minorToDecimal(row.amountMinor),
      'currency': row.currency,
      'type': row.type,
      'note': row.note,
      'settled': row.settled,
      'local_date': row.localDate,
      'created_at': row.createdAt,
      'client_updated_at': row.clientUpdatedAt,
      'deleted_at': row.deletedAt,
    };
  }

  /// Maps local [Budget] row to remote payload.
  static Map<String, dynamic> budgetToRemote(Budget row) {
    return {
      'id': row.id,
      'user_id': row.userId,
      'monthly_budget': row.monthlyMinor != null
          ? minorToDecimal(row.monthlyMinor!)
          : null,
      'weekly_budget': row.weeklyMinor != null
          ? minorToDecimal(row.weeklyMinor!)
          : null,
      'client_updated_at': row.clientUpdatedAt,
    };
  }

  /// Maps local [Contact] row to remote payload.
  static Map<String, dynamic> contactToRemote(Contact row) {
    return {
      'id': row.id,
      'user_id': row.userId,
      'name': row.name,
      'phone': row.phone,
      'note': row.note,
      'created_at': row.createdAt,
      'client_updated_at': row.clientUpdatedAt,
      'deleted_at': row.deletedAt,
    };
  }

  /// Maps local [UserCategory] row to remote payload.
  static Map<String, dynamic> userCategoryToRemote(UserCategory row) {
    return {
      'id': row.id,
      'user_id': row.userId,
      'name': row.name,
      'kind': row.kind,
      'created_at': row.createdAt,
      'client_updated_at': row.clientUpdatedAt,
      'deleted_at': row.deletedAt,
    };
  }

  /// Maps remote payload to local [ExpensesCompanion].
  static ExpensesCompanion expenseFromRemote(Map<String, dynamic> remote) {
    return ExpensesCompanion(
      id: Value(remote['id'] as String),
      userId: Value(remote['user_id'] as String),
      name: Value(remote['name'] as String),
      amountMinor: Value(decimalToMinor(remote['amount'] as num)),
      category: Value(remote['category'] as String? ?? 'Other'),
      type: Value(remote['type'] as String? ?? 'expense'),
      localDate: Value(remote['local_date'] as String),
      createdAt: Value(remote['created_at'] as String),
      clientUpdatedAt: Value(remote['client_updated_at'] as String),
      deletedAt: Value(remote['deleted_at'] as String?),
    );
  }

  /// Maps remote payload to local [CheckItemsCompanion].
  static CheckItemsCompanion checkItemFromRemote(Map<String, dynamic> remote) {
    return CheckItemsCompanion(
      id: Value(remote['id'] as String),
      userId: Value(remote['user_id'] as String),
      name: Value(remote['name'] as String),
      priceMinor: Value(decimalToMinor(remote['price'] as num)),
      uses: Value((remote['uses'] as num).toDouble()),
      costPerUseMinor: Value(
        remote['cost_per_use'] != null
            ? decimalToMinor(remote['cost_per_use'] as num)
            : null,
      ),
      verdict: Value(remote['verdict'] as String),
      regretLevel: Value((remote['regret_level'] as num).toInt()),
      localDate: Value(remote['local_date'] as String),
      createdAt: Value(remote['created_at'] as String),
      clientUpdatedAt: Value(remote['client_updated_at'] as String),
      deletedAt: Value(remote['deleted_at'] as String?),
    );
  }

  /// Maps remote payload to local [LedgerEntriesCompanion].
  static LedgerEntriesCompanion ledgerEntryFromRemote(
    Map<String, dynamic> remote,
  ) {
    return LedgerEntriesCompanion(
      id: Value(remote['id'] as String),
      userId: Value(remote['user_id'] as String),
      person: Value(remote['person'] as String),
      amountMinor: Value(decimalToMinor(remote['amount'] as num)),
      currency: Value(remote['currency'] as String? ?? 'ETB'),
      type: Value(remote['type'] as String),
      note: Value(remote['note'] as String?),
      settled: Value(remote['settled'] as bool? ?? false),
      localDate: Value(remote['local_date'] as String),
      createdAt: Value(remote['created_at'] as String),
      clientUpdatedAt: Value(remote['client_updated_at'] as String),
      deletedAt: Value(remote['deleted_at'] as String?),
    );
  }

  /// Maps remote payload to local [BudgetsCompanion].
  static BudgetsCompanion budgetFromRemote(Map<String, dynamic> remote) {
    return BudgetsCompanion(
      id: Value(remote['id'] as String),
      userId: Value(remote['user_id'] as String),
      monthlyMinor: Value(
        remote['monthly_budget'] != null
            ? decimalToMinor(remote['monthly_budget'] as num)
            : null,
      ),
      weeklyMinor: Value(
        remote['weekly_budget'] != null
            ? decimalToMinor(remote['weekly_budget'] as num)
            : null,
      ),
      updatedAt: Value(
        remote['updated_at'] as String? ??
            remote['client_updated_at'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      clientUpdatedAt: Value(
        remote['client_updated_at'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  /// Maps remote payload to local [ContactsCompanion].
  static ContactsCompanion contactFromRemote(Map<String, dynamic> remote) {
    return ContactsCompanion(
      id: Value(remote['id'] as String),
      userId: Value(remote['user_id'] as String),
      name: Value(remote['name'] as String),
      phone: Value(remote['phone'] as String?),
      note: Value(remote['note'] as String?),
      createdAt: Value(remote['created_at'] as String),
      clientUpdatedAt: Value(remote['client_updated_at'] as String),
      deletedAt: Value(remote['deleted_at'] as String?),
    );
  }

  /// Maps remote payload to local [UserCategoriesCompanion].
  static UserCategoriesCompanion userCategoryFromRemote(
    Map<String, dynamic> remote,
  ) {
    return UserCategoriesCompanion(
      id: Value(remote['id'] as String),
      userId: Value(remote['user_id'] as String),
      name: Value(remote['name'] as String),
      kind: Value(remote['kind'] as String),
      createdAt: Value(remote['created_at'] as String),
      clientUpdatedAt: Value(remote['client_updated_at'] as String),
      deletedAt: Value(remote['deleted_at'] as String?),
    );
  }
}
