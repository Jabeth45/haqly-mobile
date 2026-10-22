import 'package:haqly_mobile/domain/check_calculator.dart';

/// Qualitative labels for Value Score per docs/DOMAIN_SPEC.md.
enum ValueScoreLabel {
  smartSpender('Smart spender', 75, 100),
  onTrack('On track', 50, 74),
  needsAttention('Needs attention', 25, 49),
  reviewSpending('Review spending', 0, 24);

  const ValueScoreLabel(this.text, this.minScore, this.maxScore);

  final String text;
  final int minScore;
  final int maxScore;

  static ValueScoreLabel fromScore(int score) {
    if (score >= 75) return ValueScoreLabel.smartSpender;
    if (score >= 50) return ValueScoreLabel.onTrack;
    if (score >= 25) return ValueScoreLabel.needsAttention;
    return ValueScoreLabel.reviewSpending;
  }
}

/// Breakdown and aggregate Value Score across saved checks.
class ValueScoreResult {
  const ValueScoreResult({
    required this.score,
    required this.label,
    required this.worthPct,
    required this.maybePct,
    required this.notPct,
    required this.totalChecks,
  });

  final int score;
  final ValueScoreLabel label;
  final int worthPct;
  final int maybePct;
  final int notPct;
  final int totalChecks;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValueScoreResult &&
          runtimeType == other.runtimeType &&
          score == other.score &&
          label == other.label &&
          worthPct == other.worthPct &&
          maybePct == other.maybePct &&
          notPct == other.notPct &&
          totalChecks == other.totalChecks;

  @override
  int get hashCode =>
      score.hashCode ^
      label.hashCode ^
      worthPct.hashCode ^
      maybePct.hashCode ^
      notPct.hashCode ^
      totalChecks.hashCode;

  @override
  String toString() =>
      'ValueScoreResult(score: $score, label: ${label.text}, worth: $worthPct%, maybe: $maybePct%, not: $notPct%, total: $totalChecks)';
}

/// Computes the aggregate Value Score and breakdown.
/// Returns null when verdicts list is empty (home screen hides the card).
ValueScoreResult? calcValueScore(Iterable<dynamic> verdicts) {
  final list = verdicts.toList();
  final total = list.length;
  if (total == 0) return null;

  int worthCount = 0;
  int maybeCount = 0;
  int notCount = 0;

  for (final item in list) {
    final String wire;
    if (item is Verdict) {
      wire = item.wireValue;
    } else if (item is String) {
      wire = item.toLowerCase().trim();
    } else {
      wire = item.toString().toLowerCase().trim();
    }

    if (wire == 'worth') {
      worthCount++;
    } else if (wire == 'maybe') {
      maybeCount++;
    } else if (wire == 'not') {
      notCount++;
    }
  }

  final worthPct = (worthCount / total * 100).round();
  final maybePct = (maybeCount / total * 100).round();
  final notPct = (notCount / total * 100).round();

  final score = ((worthCount * 100 + maybeCount * 50) / total).round();
  final label = ValueScoreLabel.fromScore(score);

  return ValueScoreResult(
    score: score,
    label: label,
    worthPct: worthPct,
    maybePct: maybePct,
    notPct: notPct,
    totalChecks: total,
  );
}
