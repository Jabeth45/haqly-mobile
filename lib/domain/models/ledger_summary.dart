import 'package:haqly_mobile/domain/money.dart';

/// Aggregated summary of unsettled (open) ledger entries.
/// Follows docs/DOMAIN_SPEC.md and docs/PRD.md FR-L7, FR-HM5.
/// ETB and USD are tracked independently without exchange rate conversion (OPEN-015).
class LedgerSummary {
  const LedgerSummary({
    this.totalLentEtb = const Money.zero(currency: 'ETB'),
    this.totalBorrowedEtb = const Money.zero(currency: 'ETB'),
    this.totalLentUsd = const Money.zero(currency: 'USD'),
    this.totalBorrowedUsd = const Money.zero(currency: 'USD'),
    this.openLentCount = 0,
    this.openBorrowedCount = 0,
  });

  final Money totalLentEtb;
  final Money totalBorrowedEtb;
  final Money totalLentUsd;
  final Money totalBorrowedUsd;
  final int openLentCount;
  final int openBorrowedCount;

  /// Total count of all unsettled entries.
  int get totalOpenCount => openLentCount + openBorrowedCount;

  /// Whether any unsettled debts exist (used to toggle Home ledger summary card).
  bool get hasOpenEntries => totalOpenCount > 0;

  /// Net ETB balance (lent - borrowed).
  /// Positive means others owe user; negative means user owes others.
  int get netEtbMinorUnits =>
      totalLentEtb.minorUnits - totalBorrowedEtb.minorUnits;

  bool get isEtbNegative => netEtbMinorUnits < 0;

  /// Formats net ETB balance with proper negative sign placement (e.g. "-Br 150.00").
  String formatNetEtb({String prefix = 'Br '}) {
    if (netEtbMinorUnits < 0) {
      final absMoney = Money.fromMinorUnits(-netEtbMinorUnits, currency: 'ETB');
      return '-$prefix${Money.format(absMoney, prefix: '')}';
    }
    final money = Money.fromMinorUnits(netEtbMinorUnits, currency: 'ETB');
    return Money.format(money, prefix: prefix);
  }

  /// Net USD balance (lent - borrowed).
  int get netUsdMinorUnits =>
      totalLentUsd.minorUnits - totalBorrowedUsd.minorUnits;

  bool get isUsdNegative => netUsdMinorUnits < 0;

  /// Formats net USD balance.
  String formatNetUsd({String prefix = '\$'}) {
    if (netUsdMinorUnits < 0) {
      final absMoney = Money.fromMinorUnits(-netUsdMinorUnits, currency: 'USD');
      return '-$prefix${Money.format(absMoney, prefix: '')}';
    }
    final money = Money.fromMinorUnits(netUsdMinorUnits, currency: 'USD');
    return Money.format(money, prefix: prefix);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerSummary &&
          runtimeType == other.runtimeType &&
          totalLentEtb == other.totalLentEtb &&
          totalBorrowedEtb == other.totalBorrowedEtb &&
          totalLentUsd == other.totalLentUsd &&
          totalBorrowedUsd == other.totalBorrowedUsd &&
          openLentCount == other.openLentCount &&
          openBorrowedCount == other.openBorrowedCount;

  @override
  int get hashCode =>
      totalLentEtb.hashCode ^
      totalBorrowedEtb.hashCode ^
      totalLentUsd.hashCode ^
      totalBorrowedUsd.hashCode ^
      openLentCount.hashCode ^
      openBorrowedCount.hashCode;

  @override
  String toString() =>
      'LedgerSummary(ETB: lent=$totalLentEtb, borrowed=$totalBorrowedEtb, net=${formatNetEtb()}; USD: lent=$totalLentUsd, borrowed=$totalBorrowedUsd; openCount=$totalOpenCount)';
}
