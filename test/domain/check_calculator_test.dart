import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/domain/check_calculator.dart';

void main() {
  group('calcCheck - Domain Vector Parity', () {
    test('matches all 12 cases in docs/test_vectors/domain_vectors.json', () {
      final file = File('docs/test_vectors/domain_vectors.json');
      expect(file.existsSync(), isTrue);

      final jsonContent =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final cases = (jsonContent['calcCheck'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      for (final c in cases) {
        final price = c['price'] as num;
        final uses = c['uses'] as num;
        final expectedCost = (c['costPerUse'] as num).toDouble();
        final expectedVerdict = c['verdict'] as String;
        final expectedRegret = c['regret'] as int;

        final actual = calcCheck(price, uses);

        expect(
          actual.costPerUse,
          closeTo(expectedCost, 0.00000000001),
          reason: 'Failed costPerUse for price: $price, uses: $uses',
        );
        expect(
          actual.verdict.wireValue,
          equals(expectedVerdict),
          reason: 'Failed verdict for price: $price, uses: $uses',
        );
        expect(
          actual.regretLevel,
          equals(expectedRegret),
          reason: 'Failed regret for price: $price, uses: $uses',
        );
      }
    });

    test('exact boundary conditions behave per DOMAIN_SPEC Section 2', () {
      // 1.0 -> maybe / regret 2
      final b1 = calcCheck(1.0, 1.0);
      expect(b1.verdict, equals(Verdict.maybe));
      expect(b1.regretLevel, equals(2));

      // 3.0 -> maybe / regret 2
      final b3 = calcCheck(3.0, 1.0);
      expect(b3.verdict, equals(Verdict.maybe));
      expect(b3.regretLevel, equals(2));

      // 5.0 -> maybe / regret 3
      final b5 = calcCheck(5.0, 1.0);
      expect(b5.verdict, equals(Verdict.maybe));
      expect(b5.regretLevel, equals(3));

      // 10.0 -> not / regret 4
      final b10 = calcCheck(10.0, 1.0);
      expect(b10.verdict, equals(Verdict.not));
      expect(b10.regretLevel, equals(4));

      // 10.01 -> not / regret 5
      final bAbove10 = calcCheck(10.01, 1.0);
      expect(bAbove10.verdict, equals(Verdict.not));
      expect(bAbove10.regretLevel, equals(5));
    });

    test('invalid inputs throw ArgumentError', () {
      expect(() => calcCheck(100, 0), throwsArgumentError);
      expect(() => calcCheck(100, -5), throwsArgumentError);
      expect(() => calcCheck(-50, 10), throwsArgumentError);
    });
  });
}
