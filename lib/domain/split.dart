import 'package:haqly_mobile/domain/money.dart';

/// Represents an individual's share in a split bill.
class PersonShare {
  const PersonShare({
    required this.name,
    required this.share,
    this.isPayer = false,
  });

  final String name;
  final Money share;
  final bool isPayer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonShare &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          share == other.share &&
          isPayer == other.isPayer;

  @override
  int get hashCode => name.hashCode ^ share.hashCode ^ isPayer.hashCode;

  @override
  String toString() =>
      'PersonShare(name: $name, share: $share, isPayer: $isPayer)';
}

/// Result of splitting a bill among N people per docs/DOMAIN_SPEC.md Section 7.
class SplitResult {
  const SplitResult({
    required this.total,
    required this.shares,
    required this.payerIndex,
  });

  final Money total;
  final List<PersonShare> shares;
  final int payerIndex;

  /// The share belonging to the payer (the user's own expense).
  PersonShare get payerShare => shares[payerIndex];

  /// Entries to be logged as 'lent' in the Ledger (excluding the payer).
  List<PersonShare> get lentEntries => shares.where((s) => !s.isPayer).toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplitResult &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          payerIndex == other.payerIndex;

  @override
  int get hashCode => total.hashCode ^ payerIndex.hashCode;
}

/// Splits a total amount in integer minor units among N people.
/// Remainder santim/cents are distributed 1 unit each to the first `r` people in list order.
/// Property invariant: sum of shares == total.
SplitResult splitBill(
  Money total, {
  required int peopleCount,
  List<String>? names,
  int payerIndex = 0,
}) {
  if (peopleCount < 1) {
    throw ArgumentError.value(
      peopleCount,
      'peopleCount',
      'Must split among at least 1 person',
    );
  }
  if (payerIndex < 0 || (peopleCount > 0 && payerIndex >= peopleCount)) {
    throw ArgumentError.value(
      payerIndex,
      'payerIndex',
      'Payer index out of range',
    );
  }

  final base = total.minorUnits ~/ peopleCount;
  final remainder = total.minorUnits % peopleCount;

  final resultShares = <PersonShare>[];
  for (var i = 0; i < peopleCount; i++) {
    final santim = i < remainder ? base + 1 : base;
    final personName = (names != null && i < names.length)
        ? names[i]
        : (i == payerIndex ? 'Me' : 'Person ${i + 1}');

    resultShares.add(
      PersonShare(
        name: personName,
        share: Money.fromMinorUnits(santim, currency: total.currency),
        isPayer: i == payerIndex,
      ),
    );
  }

  return SplitResult(
    total: total,
    shares: resultShares,
    payerIndex: payerIndex,
  );
}

/// Helper returning the raw list of minor unit shares for vector validation.
List<int> splitMinorUnits(int totalMinor, int peopleCount) {
  if (peopleCount < 1) throw ArgumentError('peopleCount must be >= 1');
  final base = totalMinor ~/ peopleCount;
  final remainder = totalMinor % peopleCount;

  return List.generate(peopleCount, (i) => i < remainder ? base + 1 : base);
}
