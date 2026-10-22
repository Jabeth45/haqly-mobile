import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/domain/date_utils.dart';
import 'package:haqly_mobile/domain/streak.dart';

void main() {
  group('streak - Domain Vector Parity', () {
    test('matches all 6 cases in docs/test_vectors/domain_vectors.json', () {
      final file = File('docs/test_vectors/domain_vectors.json');
      expect(file.existsSync(), isTrue);

      final jsonContent =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final streakData = jsonContent['streak'] as Map<String, dynamic>;

      final todayStr = streakData['today'] as String;
      final today = parseLocalDate(todayStr);

      final cases = (streakData['cases'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      for (final c in cases) {
        final days = (c['days'] as List<dynamic>).cast<String>();
        final expectedStreak = c['streak'] as int;
        final expectedShown = c['shown'] as bool;

        final actual = calcStreak(days, today: today);

        expect(
          actual.currentStreak,
          equals(expectedStreak),
          reason: 'Failed streak for days: $days with today: $todayStr',
        );
        expect(
          actual.isShown,
          equals(expectedShown),
          reason: 'Failed isShown for days: $days with today: $todayStr',
        );
      }
    });

    test(
      'streak properties: longest >= current and milestones trigger correctly',
      () {
        final today = DateTime(2026, 10, 22);

        // 7-day streak has glow
        final sevenDays = List.generate(
          7,
          (i) => toLocalDateString(today.subtract(Duration(days: i))),
        );
        final res7 = calcStreak(sevenDays, today: today);
        expect(res7.currentStreak, equals(7));
        expect(res7.hasGlow, isTrue);
        expect(res7.has30DayMilestone, isFalse);
        expect(res7.longestStreak, equals(7));

        // 30-day streak has milestone
        final thirtyDays = List.generate(
          30,
          (i) => toLocalDateString(today.subtract(Duration(days: i))),
        );
        final res30 = calcStreak(thirtyDays, today: today);
        expect(res30.currentStreak, equals(30));
        expect(res30.has30DayMilestone, isTrue);
        expect(res30.longestStreak, equals(30));

        // Longest streak in past history preserves record when current broke
        final brokenCurrentWithPastStreak = [
          ...List.generate(
            10,
            (i) =>
                toLocalDateString(DateTime(2026, 5, 1).add(Duration(days: i))),
          ),
          toLocalDateString(today),
        ];
        final pastRecordRes = calcStreak(
          brokenCurrentWithPastStreak,
          today: today,
        );
        expect(pastRecordRes.currentStreak, equals(1));
        expect(pastRecordRes.longestStreak, equals(10));
      },
    );
  });
}
