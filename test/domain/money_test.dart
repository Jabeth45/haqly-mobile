import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/domain/money.dart';

void main() {
  group('Money - Domain Vector Parity', () {
    test('matches docs/test_vectors/domain_vectors.json br vectors', () {
      final file = File('docs/test_vectors/domain_vectors.json');
      expect(file.existsSync(), isTrue, reason: 'Test vectors file must exist');

      final jsonContent =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final brCases = (jsonContent['br'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      for (final testCase in brCases) {
        final expected = testCase['out'] as String;
        if (expected == 'UNSPECIFIED') {
          continue;
        }

        final input = testCase['input'];
        final actual = Money.format(input);

        expect(
          actual,
          equals(expected),
          reason: 'Failed for input: $input (type: ${input.runtimeType})',
        );
      }
    });

    test('format works directly with Money instances', () {
      const m1 = Money.fromMinorUnits(125000); // 1,250.00 ETB
      expect(Money.format(m1), equals('Br 1,250.00'));

      const m2 = Money.fromMinorUnits(50); // 0.50 ETB
      expect(Money.format(m2), equals('Br 0.50'));

      const mZero = Money.fromMinorUnits(0);
      expect(Money.format(mZero), equals('Br 0.00'));
    });
  });

  group('Money - User Input Parsing', () {
    test('parses valid integer and decimal strings into exact minor units', () {
      expect(Money.tryParse('1250')?.minorUnits, equals(125000));
      expect(Money.tryParse('1250.5')?.minorUnits, equals(125050));
      expect(Money.tryParse('1250.50')?.minorUnits, equals(125050));
      expect(Money.tryParse('0.05')?.minorUnits, equals(5));
      expect(Money.tryParse('0')?.minorUnits, equals(0));
      expect(Money.tryParse('1,250.50')?.minorUnits, equals(125050));
    });

    test('rejects negative amounts, alphabetic strings, and >2 decimals', () {
      expect(Money.tryParse('-100'), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('   '), isNull);
      expect(Money.tryParse('12.345'), isNull); // 3 decimals strictly rejected
      expect(Money.tryParse('10.999'), isNull);
      expect(Money.tryParse('12..34'), isNull);
    });
  });

  group('Money - Arithmetic Operations', () {
    test('addition and multiplication work without float drift', () {
      const m1 = Money.fromMinorUnits(10050); // 100.50
      const m2 = Money.fromMinorUnits(20025); // 200.25
      final sum = m1 + m2;
      expect(sum.minorUnits, equals(30075));
      expect(sum.toString(), equals('Br 300.75'));

      final product = m1 * 2;
      expect(product.minorUnits, equals(20100));
      expect(product.toString(), equals('Br 201.00'));
    });

    test('subtraction succeeds when valid and throws on underflow', () {
      const m1 = Money.fromMinorUnits(20000);
      const m2 = Money.fromMinorUnits(5000);
      expect((m1 - m2).minorUnits, equals(15000));

      expect(() => m2 - m1, throwsArgumentError);
    });

    test('currencies must match on operations', () {
      const etb = Money.fromMinorUnits(100, currency: 'ETB');
      const usd = Money.fromMinorUnits(100, currency: 'USD');
      expect(() => etb + usd, throwsArgumentError);
    });
  });
}
