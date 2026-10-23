/// Supported ledger entry types.
/// Follows docs/DOMAIN_SPEC.md and docs/ARCHITECTURE.md.
/// Pure Dart (no external dependencies).
enum LedgerType {
  lent('lent'),
  borrowed('borrowed');

  const LedgerType(this.wireValue);

  final String wireValue;

  static LedgerType fromString(String value) {
    return value.toLowerCase() == 'borrowed'
        ? LedgerType.borrowed
        : LedgerType.lent;
  }
}
