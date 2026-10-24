/// Category classification kind (expense or income).
/// Follows docs/DOMAIN_SPEC.md and docs/PRD.md. Pure Dart only.
enum CategoryKind {
  expense('expense'),
  income('income');

  const CategoryKind(this.wireValue);
  final String wireValue;

  static CategoryKind fromString(String value) {
    return value.toLowerCase() == 'income'
        ? CategoryKind.income
        : CategoryKind.expense;
  }
}
