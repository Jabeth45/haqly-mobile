import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/domain/balance_calculator.dart';
import 'package:haqly_mobile/domain/money.dart';

void main() {
  group('Balance & Budget Ring - Domain Vector Parity', () {
    test('matches docs/test_vectors/domain_vectors.json balance cases', () {
      final file = File('docs/test_vectors/domain_vectors.json');
      expect(file.existsSync(), isTrue);

      final jsonContent =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final balanceData = jsonContent['balance'] as Map<String, dynamic>;
      final cases = (balanceData['cases'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      for (final c in cases) {
        final incomeMinor = c['incomeMinor'] as int;
        final expenseMinor = c['expenseMinor'] as int;
        final expectedLeft = c['leftMinor'] as int;
        final expectedSpentPct = c['spentPctOfIncome'] as int;

        final balance = MonthBalance(
          income: Money.fromMinorUnits(incomeMinor),
          expense: Money.fromMinorUnits(expenseMinor),
        );

        expect(balance.leftMinorUnits, equals(expectedLeft));
        expect(balance.spentPctOfIncome, equals(expectedSpentPct));
        expect(balance.hasIncome, isTrue);
        expect(balance.isNegative, isFalse);
      }
    });

    test('negative left balance formats correctly with negative sign', () {
      const balance = MonthBalance(
        income: Money.fromMinorUnits(50000), // 500 ETB
        expense: Money.fromMinorUnits(75000), // 750 ETB
      );

      expect(balance.leftMinorUnits, equals(-25000));
      expect(balance.isNegative, isTrue);
      expect(balance.formatLeft(), equals('-Br 250.00'));
    });

    test(
      'BudgetRing ceiling priority and alert thresholds trigger correctly',
      () {
        // Manual budget takes priority over income ceiling
        const ringWithBoth = BudgetRing(
          manualBudget: Money.fromMinorUnits(200000), // 2,000 ETB
          incomeCeiling: Money.fromMinorUnits(300000), // 3,000 ETB
          spent: Money.fromMinorUnits(
            160000,
          ), // 1,600 ETB (80% of manual budget)
        );

        expect(ringWithBoth.activeCeiling?.minorUnits, equals(200000));
        expect(ringWithBoth.spentPercentage, equals(80));
        expect(ringWithBoth.has80PercentAlert, isTrue);
        expect(ringWithBoth.has100PercentAlert, isFalse);

        // 100% alert when spent >= budget
        const ring100 = BudgetRing(
          manualBudget: Money.fromMinorUnits(200000),
          spent: Money.fromMinorUnits(210000), // 105%
        );
        expect(ring100.spentPercentage, equals(105));
        expect(ring100.has80PercentAlert, isTrue);
        expect(ring100.has100PercentAlert, isTrue);

        // Falls back to income ceiling when manual budget is absent
        const ringIncomeOnly = BudgetRing(
          incomeCeiling: Money.fromMinorUnits(100000),
          spent: Money.fromMinorUnits(50000),
        );
        expect(ringIncomeOnly.activeCeiling?.minorUnits, equals(100000));
        expect(ringIncomeOnly.spentPercentage, equals(50));
        expect(ringIncomeOnly.has80PercentAlert, isFalse);

        // Null ceiling when neither is available
        const ringEmpty = BudgetRing(spent: Money.fromMinorUnits(50000));
        expect(ringEmpty.activeCeiling, isNull);
        expect(ringEmpty.progress, isNull);
        expect(ringEmpty.spentPercentage, isNull);
      },
    );
  });
}
