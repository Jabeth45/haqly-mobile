import 'package:haqly_mobile/domain/models/transaction_type.dart';
import 'package:haqly_mobile/domain/money.dart';

/// Pure Dart Expense entity representing both expenses and income entries.
/// Follows docs/DOMAIN_SPEC.md and docs/ARCHITECTURE.md.
class Expense {
  const Expense({
    required this.id,
    this.userId = 'LOCAL',
    required this.name,
    required this.amount,
    this.category = 'Other',
    this.type = TransactionType.expense,
    required this.localDate,
    required this.createdAt,
    required this.clientUpdatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final Money amount;
  final String category;
  final TransactionType type;

  /// Device-local date string 'YYYY-MM-DD' at creation time.
  final String localDate;

  final DateTime createdAt;
  final DateTime clientUpdatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;

  Expense copyWith({
    String? id,
    String? userId,
    String? name,
    Money? amount,
    String? category,
    TransactionType? type,
    String? localDate,
    DateTime? createdAt,
    DateTime? clientUpdatedAt,
    DateTime? deletedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      type: type ?? this.type,
      localDate: localDate ?? this.localDate,
      createdAt: createdAt ?? this.createdAt,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          amount == other.amount &&
          category == other.category &&
          type == other.type &&
          localDate == other.localDate &&
          createdAt == other.createdAt &&
          clientUpdatedAt == other.clientUpdatedAt &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      name.hashCode ^
      amount.hashCode ^
      category.hashCode ^
      type.hashCode ^
      localDate.hashCode ^
      createdAt.hashCode ^
      clientUpdatedAt.hashCode ^
      deletedAt.hashCode;

  @override
  String toString() =>
      'Expense(id: $id, userId: $userId, name: $name, amount: ${Money.format(amount)}, category: $category, type: $type, localDate: $localDate, isDeleted: $isDeleted)';
}
