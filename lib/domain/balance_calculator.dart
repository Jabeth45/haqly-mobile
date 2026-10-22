import 'package:haqly_mobile/domain/money.dart';

/// Monthly balance calculations per docs/DOMAIN_SPEC.md Section 6.
class MonthBalance {
  const MonthBalance({required this.income, required this.expense});

  final Money income;
  final Money expense;

  /// left = income - expense (can be negative if spent > earned).
  int get leftMinorUnits => income.minorUnits - expense.minorUnits;

  bool get isNegative => leftMinorUnits < 0;

  /// Balance strip is visible only if at least one income entry exists in the month.
  bool get hasIncome => income.minorUnits > 0;

  /// Percentage of month's income that has been spent.
  int get spentPctOfIncome {
    if (income.minorUnits <= 0) return 0;
    return (expense.minorUnits / income.minorUnits * 100).round();
  }

  /// Formats the left balance nicely, correctly placing minus sign for negative amounts.
  String formatLeft({String prefix = 'Br '}) {
    if (leftMinorUnits < 0) {
      final absMoney = Money.fromMinorUnits(
        -leftMinorUnits,
        currency: income.currency,
      );
      return '-$prefix${Money.format(absMoney, prefix: '')}';
    }
    final money = Money.fromMinorUnits(
      leftMinorUnits,
      currency: income.currency,
    );
    return Money.format(money, prefix: prefix);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthBalance &&
          runtimeType == other.runtimeType &&
          income == other.income &&
          expense == other.expense;

  @override
  int get hashCode => income.hashCode ^ expense.hashCode;

  @override
  String toString() =>
      'MonthBalance(income: $income, expense: $expense, left: ${formatLeft()}, spentPct: $spentPctOfIncome%)';
}

/// Computes budget progress ring state and alert thresholds.
class BudgetRing {
  const BudgetRing({
    this.manualBudget,
    this.incomeCeiling,
    required this.spent,
  });

  final Money? manualBudget;
  final Money? incomeCeiling;
  final Money spent;

  /// Ceiling priority: manual monthly budget if set; else monthly income if income exists; else null.
  Money? get activeCeiling {
    if (manualBudget != null && manualBudget!.minorUnits > 0) {
      return manualBudget;
    }
    if (incomeCeiling != null && incomeCeiling!.minorUnits > 0) {
      return incomeCeiling;
    }
    return null;
  }

  /// Progress from 0.0 to 1.0 (can exceed 1.0 if over budget). Returns null if no ceiling.
  double? get progress {
    final ceiling = activeCeiling;
    if (ceiling == null || ceiling.minorUnits <= 0) return null;
    return spent.minorUnits / ceiling.minorUnits;
  }

  /// Integer percentage of budget used. Returns null if no budget or income ceiling.
  int? get spentPercentage {
    final prog = progress;
    if (prog == null) return null;
    return (prog * 100).round();
  }

  /// 80% alert threshold.
  bool get has80PercentAlert {
    final ceiling = manualBudget ?? incomeCeiling;
    if (ceiling == null || ceiling.minorUnits <= 0) return false;
    return (spent.minorUnits / ceiling.minorUnits) >= 0.80;
  }

  /// 100% budget reached alert threshold.
  bool get has100PercentAlert {
    final ceiling = manualBudget ?? incomeCeiling;
    if (ceiling == null || ceiling.minorUnits <= 0) return false;
    return (spent.minorUnits / ceiling.minorUnits) >= 1.00;
  }
}
