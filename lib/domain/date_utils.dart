import 'package:haqly_mobile/core/services/clock.dart';
import 'package:intl/intl.dart';

/// Pure Dart date helpers following docs/DOMAIN_SPEC.md Section 4.
/// No Flutter or Drift dependencies.

/// Computes greeting based on 24-hour hour integer (0..23).
/// hour < 12 -> Good morning
/// hour < 18 -> Good afternoon
/// else -> Good evening
String greeting(int hour) {
  if (hour < 0 || hour > 23) {
    throw ArgumentError.value(hour, 'hour', 'Hour must be between 0 and 23');
  }

  if (hour < 12) {
    return 'Good morning';
  } else if (hour < 18) {
    return 'Good afternoon';
  } else {
    return 'Good evening';
  }
}

/// Formats a DateTime into a device-local 'YYYY-MM-DD' string.
/// Stored in the local_date column to avoid UTC timezone midnight errors.
String toLocalDateString(DateTime dateTime) {
  final y = dateTime.year.toString().padLeft(4, '0');
  final m = dateTime.month.toString().padLeft(2, '0');
  final d = dateTime.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses a 'YYYY-MM-DD' string into a local DateTime at midnight.
DateTime parseLocalDate(String localDateString) {
  final parts = localDateString.split('-');
  if (parts.length != 3) {
    throw FormatException('Invalid local date string: $localDateString');
  }
  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final d = int.parse(parts[2]);
  return DateTime(y, m, d);
}

/// Returns a human-friendly day label comparing calendar dates in local time.
/// Today -> "Today"
/// Yesterday -> "Yesterday"
/// else -> "Tuesday, Oct 20" style (weekday long, month short, day numeric)
String dayLabel(
  DateTime targetDate, {
  Clock clock = const SystemClock(),
  String locale = 'en',
}) {
  final now = clock.now();
  final targetLocal = targetDate.toLocal();
  final nowLocal = now.toLocal();

  final nowDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final targetDay = DateTime(
    targetLocal.year,
    targetLocal.month,
    targetLocal.day,
  );

  final diffDays = nowDate.difference(targetDay).inDays;

  if (diffDays == 0) {
    return locale == 'am' ? 'ዛሬ' : 'Today';
  } else if (diffDays == 1) {
    return locale == 'am' ? 'ትናንት' : 'Yesterday';
  } else {
    return DateFormat('EEEE, MMM d', locale).format(targetLocal);
  }
}
