import 'package:haqly_mobile/domain/date_utils.dart';

/// Immutable result of streak calculation per docs/DOMAIN_SPEC.md Section 5.
class StreakResult {
  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
  });

  final int currentStreak;
  final int longestStreak;

  /// Visible on Home screen only when current streak >= 3 days.
  bool get isShown => currentStreak >= 3;

  /// Subtle glow milestone on badge at >= 7 days.
  bool get hasGlow => currentStreak >= 7;

  /// 30-day milestone reached.
  bool get has30DayMilestone => currentStreak >= 30;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakResult &&
          runtimeType == other.runtimeType &&
          currentStreak == other.currentStreak &&
          longestStreak == other.longestStreak;

  @override
  int get hashCode => currentStreak.hashCode ^ longestStreak.hashCode;

  @override
  String toString() =>
      'StreakResult(current: $currentStreak, longest: $longestStreak, shown: $isShown, glow: $hasGlow)';
}

/// Computes current and longest streak across unique active local dates (YYYY-MM-DD).
/// An active day has at least one non-deleted expense or income entry.
StreakResult calcStreak(
  Iterable<String> activeLocalDates, {
  required DateTime today,
}) {
  final activeSet = activeLocalDates.toSet();
  if (activeSet.isEmpty) {
    return const StreakResult(currentStreak: 0, longestStreak: 0);
  }

  final todayLocal = DateTime(today.year, today.month, today.day);
  final todayStr = toLocalDateString(todayLocal);
  final yesterdayLocal = todayLocal.subtract(const Duration(days: 1));
  final yesterdayStr = toLocalDateString(yesterdayLocal);

  // 1. Calculate Current Streak
  int current = 0;
  DateTime walkDate;

  if (activeSet.contains(todayStr)) {
    walkDate = todayLocal;
  } else if (activeSet.contains(yesterdayStr)) {
    // Day not over yet; streak remains alive from yesterday
    walkDate = yesterdayLocal;
  } else {
    walkDate =
        todayLocal; // Neither today nor yesterday has activity -> reset to 0
  }

  if (activeSet.contains(toLocalDateString(walkDate))) {
    while (activeSet.contains(toLocalDateString(walkDate))) {
      current++;
      walkDate = walkDate.subtract(const Duration(days: 1));
    }
  }

  // 2. Calculate Longest Streak in history
  final parsedDates =
      activeSet
          .map((d) {
            try {
              return parseLocalDate(d);
            } catch (_) {
              return null;
            }
          })
          .whereType<DateTime>()
          .toList()
        ..sort();

  int longest = 0;
  int running = 0;
  DateTime? prev;

  for (final date in parsedDates) {
    if (prev == null) {
      running = 1;
    } else {
      final diff = date.difference(prev).inDays;
      if (diff == 1) {
        running++;
      } else if (diff > 1) {
        running = 1;
      }
      // If diff == 0, duplicate date in set: ignore
    }
    prev = date;
    if (running > longest) {
      longest = running;
    }
  }

  if (current > longest) {
    longest = current;
  }

  return StreakResult(currentStreak: current, longestStreak: longest);
}
