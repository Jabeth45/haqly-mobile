/// Possible pre-purchase verdicts per docs/DOMAIN_SPEC.md.
enum Verdict {
  worth('worth', 'WORTH IT'),
  maybe('maybe', 'MAYBE'),
  not('not', 'SKIP IT');

  const Verdict(this.wireValue, this.displayLabel);

  final String wireValue;
  final String displayLabel;

  static Verdict fromWire(String value) {
    return Verdict.values.firstWhere(
      (v) => v.wireValue == value,
      orElse: () => throw ArgumentError('Unknown verdict: $value'),
    );
  }
}

/// Immutable result of a pre-purchase value check.
class CheckResult {
  const CheckResult({
    required this.costPerUse,
    required this.verdict,
    required this.regretLevel,
  }) : assert(
         regretLevel >= 1 && regretLevel <= 5,
         'Regret must be between 1 and 5',
       );

  final double costPerUse;
  final Verdict verdict;
  final int regretLevel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckResult &&
          runtimeType == other.runtimeType &&
          costPerUse == other.costPerUse &&
          verdict == other.verdict &&
          regretLevel == other.regretLevel;

  @override
  int get hashCode =>
      costPerUse.hashCode ^ verdict.hashCode ^ regretLevel.hashCode;

  @override
  String toString() =>
      'CheckResult(costPerUse: $costPerUse, verdict: ${verdict.wireValue}, regret: $regretLevel)';
}

/// Pre-purchase calculator matching web app logic exactly.
/// Computed in Birr as doubles per DOMAIN_SPEC Section 2.
CheckResult calcCheck(num price, num uses) {
  if (uses <= 0) {
    throw ArgumentError.value(
      uses,
      'uses',
      'Uses must be strictly greater than 0',
    );
  }
  if (price < 0) {
    throw ArgumentError.value(price, 'price', 'Price cannot be negative');
  }

  final costPerUse = price / uses;

  final Verdict verdict;
  if (costPerUse < 1.0) {
    verdict = Verdict.worth;
  } else if (costPerUse <= 5.0) {
    verdict = Verdict.maybe;
  } else {
    verdict = Verdict.not;
  }

  final int regret;
  if (costPerUse < 1.0) {
    regret = 1;
  } else if (costPerUse <= 3.0) {
    regret = 2;
  } else if (costPerUse <= 5.0) {
    regret = 3;
  } else if (costPerUse <= 10.0) {
    regret = 4;
  } else {
    regret = 5;
  }

  return CheckResult(
    costPerUse: costPerUse,
    verdict: verdict,
    regretLevel: regret,
  );
}
