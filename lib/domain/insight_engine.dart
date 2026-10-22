import 'package:haqly_mobile/domain/money.dart';

/// Types of rule-based financial insights per docs/DOMAIN_SPEC.md Section 8.
enum InsightType {
  /// 50%+ of check verdicts are 'not' -> warn about purchase quality
  purchaseQualityWarning,

  /// 80%+ of check verdicts are 'worth' -> reinforce smart spending
  smartSpendingReinforcement,

  /// Spending exceeds total income for the current month
  incomeExceeded,

  /// Spending exceeds 75% of income for the current month
  incomeHighUsage,

  /// One category represents > 50% of total expense spend
  dominantCategory,

  /// Nothing logged today -> nudge user to record daily spend
  noEntriesToday,

  /// 10+ expenses logged in history -> patterns are emerging
  patternsEmerging,

  /// Default baseline -> consistency nudge
  consistencyNudge,
}

/// Typed representation of a generated insight with dynamic parameters.
/// UI widgets map [type] and [params] to localized ARB strings without inventing copy.
class Insight {
  const Insight({required this.type, this.params = const {}});

  final InsightType type;
  final Map<String, dynamic> params;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Insight &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          _mapsEqual(params, other.params);

  @override
  int get hashCode => type.hashCode ^ params.length.hashCode;

  @override
  String toString() => 'Insight(type: $type, params: $params)';

  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Snapshot of aggregated metrics passed to the insight rule engine.
class InsightContext {
  const InsightContext({
    this.totalChecks = 0,
    this.worthChecks = 0,
    this.maybeChecks = 0,
    this.notChecks = 0,
    this.todayEntriesCount = 0,
    this.totalExpensesCount = 0,
    this.totalSpend = const Money.zero(),
    this.categorySpends = const {},
    this.monthIncome,
    this.monthExpense,
    this.enableIncomeInsights = false,
  });

  final int totalChecks;
  final int worthChecks;
  final int maybeChecks;
  final int notChecks;
  final int todayEntriesCount;
  final int totalExpensesCount;
  final Money totalSpend;
  final Map<String, Money> categorySpends;
  final Money? monthIncome;
  final Money? monthExpense;
  final bool enableIncomeInsights;
}

/// Rule definition for the insight pipeline.
typedef InsightRule = Insight? Function(InsightContext context);

/// Generates the highest-priority matching insight for the given context.
Insight generateInsight(
  InsightContext context, {
  List<InsightRule>? customRules,
}) {
  final rules = customRules ?? defaultInsightRules;

  for (final rule in rules) {
    final result = rule(context);
    if (result != null) {
      return result;
    }
  }

  return const Insight(type: InsightType.consistencyNudge);
}

/// Canonical rules list ordered by priority per DOMAIN_SPEC Section 8.
final List<InsightRule> defaultInsightRules = [
  // 1. 50%+ of check verdicts are 'not'
  (context) {
    if (context.totalChecks > 0) {
      final notRatio = context.notChecks / context.totalChecks;
      if (notRatio >= 0.50) {
        return const Insight(type: InsightType.purchaseQualityWarning);
      }
    }
    return null;
  },

  // 2. 80%+ of check verdicts are 'worth'
  (context) {
    if (context.totalChecks > 0) {
      final worthRatio = context.worthChecks / context.totalChecks;
      if (worthRatio >= 0.80) {
        return const Insight(type: InsightType.smartSpendingReinforcement);
      }
    }
    return null;
  },

  // Income Rule A (when enabled per OPEN-005): monthExpense > monthIncome
  (context) {
    if (context.enableIncomeInsights &&
        context.monthIncome != null &&
        context.monthExpense != null) {
      if (context.monthIncome!.minorUnits > 0 &&
          context.monthExpense!.minorUnits > context.monthIncome!.minorUnits) {
        return const Insight(type: InsightType.incomeExceeded);
      }
    }
    return null;
  },

  // Income Rule B (when enabled): monthExpense > 75% of monthIncome
  (context) {
    if (context.enableIncomeInsights &&
        context.monthIncome != null &&
        context.monthExpense != null) {
      if (context.monthIncome!.minorUnits > 0) {
        final ratio =
            context.monthExpense!.minorUnits / context.monthIncome!.minorUnits;
        if (ratio >= 0.75) {
          // Find dominant category for this month
          String? topCat;
          int topMinor = 0;
          for (final entry in context.categorySpends.entries) {
            if (entry.value.minorUnits > topMinor) {
              topMinor = entry.value.minorUnits;
              topCat = entry.key;
            }
          }
          final params = <String, dynamic>{'percentage': (ratio * 100).round()};
          if (topCat != null) {
            params['topCategory'] = topCat;
          }
          return Insight(type: InsightType.incomeHighUsage, params: params);
        }
      }
    }
    return null;
  },

  // 3. One category represents > 50% of total spend
  (context) {
    if (context.totalSpend.minorUnits > 0 &&
        context.categorySpends.isNotEmpty) {
      for (final entry in context.categorySpends.entries) {
        final categorySpend = entry.value.minorUnits;
        final ratio = categorySpend / context.totalSpend.minorUnits;
        if (ratio > 0.50) {
          return Insight(
            type: InsightType.dominantCategory,
            params: {
              'category': entry.key,
              'percentage': (ratio * 100).round(),
            },
          );
        }
      }
    }
    return null;
  },

  // 4. Nothing logged today
  (context) {
    if (context.todayEntriesCount == 0) {
      return const Insight(type: InsightType.noEntriesToday);
    }
    return null;
  },

  // 5. 10+ expenses total logged in history
  (context) {
    if (context.totalExpensesCount >= 10) {
      return const Insight(type: InsightType.patternsEmerging);
    }
    return null;
  },

  // 6. Default consistency nudge
  (_) => const Insight(type: InsightType.consistencyNudge),
];
