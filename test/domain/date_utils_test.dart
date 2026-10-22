import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/domain/date_utils.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  group('greeting - Domain Vector Parity', () {
    test(
      'matches all greeting cases in docs/test_vectors/domain_vectors.json',
      () {
        final file = File('docs/test_vectors/domain_vectors.json');
        expect(file.existsSync(), isTrue);

        final jsonContent =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final cases = (jsonContent['greeting'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

        for (final c in cases) {
          final hour = c['hour'] as int;
          final expected = c['text'] as String;
          final actual = greeting(hour);

          expect(actual, equals(expected), reason: 'Failed for hour: $hour');
        }
      },
    );

    test('invalid hours throw ArgumentError', () {
      expect(() => greeting(-1), throwsArgumentError);
      expect(() => greeting(24), throwsArgumentError);
    });
  });

  group('dayLabel - Domain Vector Parity', () {
    test(
      'matches all dayLabel cases in docs/test_vectors/domain_vectors.json',
      () {
        final file = File('docs/test_vectors/domain_vectors.json');
        expect(file.existsSync(), isTrue);

        final jsonContent =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final dayLabelData = jsonContent['dayLabel'] as Map<String, dynamic>;

        final nowLocalStr = dayLabelData['nowLocal'] as String;
        final fixedNow = DateTime.parse(nowLocalStr);
        final clock = FixedClock(fixedNow);

        final cases = (dayLabelData['cases'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

        for (final c in cases) {
          final dateStr = c['date'] as String;
          final targetDate = parseLocalDate(dateStr);
          final expected = c['out'] as String;

          final actual = dayLabel(targetDate, clock: clock, locale: 'en');

          expect(
            actual,
            equals(expected),
            reason: 'Failed for date: $dateStr with nowLocal: $nowLocalStr',
          );
        }
      },
    );

    test('local date formatting and parsing is idempotent', () {
      final dt = DateTime(2026, 10, 22, 14, 30);
      final str = toLocalDateString(dt);
      expect(str, equals('2026-10-22'));

      final parsed = parseLocalDate(str);
      expect(parsed.year, equals(2026));
      expect(parsed.month, equals(10));
      expect(parsed.day, equals(22));
    });
  });
}
