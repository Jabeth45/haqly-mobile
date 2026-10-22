import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/domain/insight_engine.dart';
import 'package:haqly_mobile/domain/money.dart';

void main() {
  group('InsightEngine - Priority & Rule Evaluation', () {
    test(
      'Rule 1: triggers purchaseQualityWarning when >= 50% checks are not',
      () {
        const context = InsightContext(
          totalChecks: 10,
          notChecks: 5,
          worthChecks: 5,
          todayEntriesCount:
              0, // Rule 4 also matches, but Rule 1 takes precedence
        );

        final insight = generateInsight(context);
        expect(insight.type, equals(InsightType.purchaseQualityWarning));
      },
    );

    test('Rule 2: triggers smartSpendingReinforcement when >= 80% checks are worth', () {
      const context = InsightContext(
        totalChecks: 10,
        worthChecks: 8,
        maybeChecks: 2,
        notChecks: 0,
      );

      final insight = generateInsight(context);
      expect(insight.type, equals(InsightType.smartSpendingReinforcement));
    });

    test(
      'Rule 3: triggers dominantCategory when single category > 50% of spend',
      () {
        const context = InsightContext(
          totalChecks: 2,
          worthChecks: 1,
          notChecks: 0,
          todayEntriesCount: 1,
          totalSpend: Money.fromMinorUnits(10000), // 100 ETB
          categorySpends: {
            'Meals': Money.fromMinorUnits(6000), // 60%
            'Transport': Money.fromMinorUnits(4000), // 40%
          },
        );

        final insight = generateInsight(context);
        expect(insight.type, equals(InsightType.dominantCategory));
        expect(insight.params['category'], equals('Meals'));
        expect(insight.params['percentage'], equals(60));
      },
    );

    test('Rule 4: triggers noEntriesToday when nothing logged today', () {
      const context = InsightContext(
        totalChecks: 0,
        todayEntriesCount: 0,
        totalExpensesCount: 20, // Rule 5 matches, but Rule 4 takes precedence
      );

      final insight = generateInsight(context);
      expect(insight.type, equals(InsightType.noEntriesToday));
    });

    test('Rule 5: triggers patternsEmerging when 10+ expenses exist and today has entries', () {
      const context = InsightContext(
        totalChecks: 0,
        todayEntriesCount: 2,
        totalExpensesCount: 15,
      );

      final insight = generateInsight(context);
      expect(insight.type, equals(InsightType.patternsEmerging));
    });

    test(
      'Rule 6: triggers consistencyNudge when no other conditions are met',
      () {
        const context = InsightContext(
          totalChecks: 0,
          todayEntriesCount: 1,
          totalExpensesCount: 4,
        );

        final insight = generateInsight(context);
        expect(insight.type, equals(InsightType.consistencyNudge));
      },
    );

    test('Income rules evaluate when enableIncomeInsights is true', () {
      const exceededContext = InsightContext(
        enableIncomeInsights: true,
        monthIncome: Money.fromMinorUnits(100000), // 1,000 ETB
        monthExpense: Money.fromMinorUnits(120000), // 1,200 ETB
        todayEntriesCount: 1,
      );
      expect(
        generateInsight(exceededContext).type,
        equals(InsightType.incomeExceeded),
      );

      const highUsageContext = InsightContext(
        enableIncomeInsights: true,
        monthIncome: Money.fromMinorUnits(100000), // 1,000 ETB
        monthExpense: Money.fromMinorUnits(80000), // 800 ETB (80%)
        categorySpends: {
          'Transport': Money.fromMinorUnits(50000),
          'Meals': Money.fromMinorUnits(30000),
        },
        todayEntriesCount: 1,
      );
      final highInsight = generateInsight(highUsageContext);
      expect(highInsight.type, equals(InsightType.incomeHighUsage));
      expect(highInsight.params['percentage'], equals(80));
      expect(highInsight.params['topCategory'], equals('Transport'));
    });
  });
}
