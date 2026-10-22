import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/domain/money.dart';
import 'package:haqly_mobile/domain/split.dart';

void main() {
  group('split - Domain Vector Parity', () {
    test('matches all cases in docs/test_vectors/domain_vectors.json', () {
      final file = File('docs/test_vectors/domain_vectors.json');
      expect(file.existsSync(), isTrue);

      final jsonContent =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final splitData = jsonContent['split'] as Map<String, dynamic>;
      final cases = (splitData['cases'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      for (final c in cases) {
        final totalMinor = c['totalMinor'] as int;
        final people = c['people'] as int;
        final expectedShares = (c['sharesMinor'] as List<dynamic>).cast<int>();

        final actual = splitMinorUnits(totalMinor, people);

        expect(
          actual,
          equals(expectedShares),
          reason: 'Failed split for total: $totalMinor, people: $people',
        );
      }
    });

    test('splitBill constructs valid PersonShares and identifies payer', () {
      const total = Money.fromMinorUnits(100000); // 1,000.00 ETB
      final result = splitBill(
        total,
        peopleCount: 4,
        names: ['Me', 'Abebe', 'Almaz', 'Dawit'],
        payerIndex: 0,
      );

      expect(result.shares.length, equals(4));
      expect(result.payerShare.name, equals('Me'));
      expect(result.payerShare.share.minorUnits, equals(25000));
      expect(result.payerShare.isPayer, isTrue);

      final lent = result.lentEntries;
      expect(lent.length, equals(3));
      expect(
        lent.map((p) => p.name).toList(),
        equals(['Abebe', 'Almaz', 'Dawit']),
      );
      for (final friend in lent) {
        expect(friend.share.minorUnits, equals(25000));
        expect(friend.isPayer, isFalse);
      }
    });

    test('property: sum of shares ALWAYS equals total exactly across 1000 randomized splits', () {
      final rng = Random(42);

      for (var i = 0; i < 1000; i++) {
        final totalSantim = rng.nextInt(5000000) + 1; // 1 santim to 50,000 Birr
        final peopleCount = rng.nextInt(30) + 1; // 1 to 30 people

        final totalMoney = Money.fromMinorUnits(totalSantim);
        final result = splitBill(totalMoney, peopleCount: peopleCount);

        final sumOfShares = result.shares.fold<int>(
          0,
          (acc, p) => acc + p.share.minorUnits,
        );

        expect(
          sumOfShares,
          equals(totalSantim),
          reason:
              'Invariant failed: sum $sumOfShares != total $totalSantim (people: $peopleCount)',
        );
      }
    });
  });
}
