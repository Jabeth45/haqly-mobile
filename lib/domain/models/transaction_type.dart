/// Supported transaction types for money entries.
/// Follows docs/DOMAIN_SPEC.md. Pure Dart only.
enum TransactionType {
  expense,
  income;

  static TransactionType fromString(String value) {
    return value.toLowerCase() == 'income'
        ? TransactionType.income
        : TransactionType.expense;
  }
}
