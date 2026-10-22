import 'package:intl/intl.dart';

/// Pure Dart Money value type.
/// Amounts are stored strictly as integer minor units (santim / cents).
/// 1 Birr = 100 santim; 1 USD = 100 cents.
/// Follows docs/DOMAIN_SPEC.md. No Flutter or database dependencies.
class Money implements Comparable<Money> {
  const Money.fromMinorUnits(this.minorUnits, {this.currency = defaultCurrency})
    : assert(minorUnits >= 0, 'Money cannot be negative in local storage');

  const Money.zero({this.currency = defaultCurrency}) : minorUnits = 0;

  final int minorUnits;
  final String currency;

  static const String defaultCurrency = 'ETB';
  static final NumberFormat _commaFormatter = NumberFormat('#,##0', 'en_US');

  /// Human-readable Birr amount as double (only for domain calculations/verdict).
  double get toMajorDouble => minorUnits / 100.0;

  /// Formats any input (Money, num, numeric string) into standard "Br 1,250.00".
  /// Fallbacks to "Br 0.00" on unparseable, non-finite or negative values.
  static String format(dynamic input, {String prefix = 'Br '}) {
    if (input == null) return '${prefix}0.00';

    if (input is Money) {
      return _formatMinor(input.minorUnits, prefix: prefix);
    }

    if (input is int) {
      if (input < 0) return '${prefix}0.00';
      // If integer is passed directly as major units (e.g. 1250 -> 1,250.00)
      return '$prefix${_commaFormatter.format(input)}.00';
    }

    if (input is double) {
      if (!input.isFinite || input < 0) return '${prefix}0.00';
      return _formatDouble(input, prefix: prefix);
    }

    if (input is String) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) return '${prefix}0.00';

      final parsed = double.tryParse(trimmed);
      if (parsed == null || !parsed.isFinite || parsed < 0) {
        return '${prefix}0.00';
      }
      return _formatDouble(parsed, prefix: prefix);
    }

    return '${prefix}0.00';
  }

  static String _formatMinor(int minor, {String prefix = 'Br '}) {
    final major = minor ~/ 100;
    final cents = minor % 100;
    final formattedMajor = _commaFormatter.format(major);
    final formattedCents = cents.toString().padLeft(2, '0');
    return '$prefix$formattedMajor.$formattedCents';
  }

  static String _formatDouble(double value, {String prefix = 'Br '}) {
    // Avoid double rounding drift by using fixed 2 decimal conversion
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final major = int.tryParse(parts[0]) ?? 0;
    final cents = parts.length > 1 ? parts[1] : '00';
    return '$prefix${_commaFormatter.format(major)}.$cents';
  }

  /// Parses user-typed input string into minor units.
  /// Rejects negative amounts, non-digits, and more than 2 decimal digits.
  /// Returns null if input is invalid.
  static Money? tryParse(String rawInput, {String currency = defaultCurrency}) {
    final trimmed = rawInput.trim().replaceAll(',', '');
    if (trimmed.isEmpty) return null;

    // Reject negative
    if (trimmed.startsWith('-')) return null;

    // Must be valid decimal format: digits, optional dot, at most 2 decimals
    final regex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!regex.hasMatch(trimmed)) return null;

    final parts = trimmed.split('.');
    final major = int.tryParse(parts[0]);
    if (major == null) return null;

    int cents = 0;
    if (parts.length > 1) {
      final centsPart = parts[1];
      if (centsPart.length == 1) {
        cents = (int.tryParse(centsPart) ?? 0) * 10;
      } else if (centsPart.length == 2) {
        cents = int.tryParse(centsPart) ?? 0;
      }
    }

    final totalMinor = (major * 100) + cents;
    return Money.fromMinorUnits(totalMinor, currency: currency);
  }

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money.fromMinorUnits(
      minorUnits + other.minorUnits,
      currency: currency,
    );
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    final result = minorUnits - other.minorUnits;
    if (result < 0) {
      throw ArgumentError('Money subtraction resulted in negative balance.');
    }
    return Money.fromMinorUnits(result, currency: currency);
  }

  Money operator *(num factor) {
    if (factor < 0) {
      throw ArgumentError('Cannot multiply Money by negative factor.');
    }
    final result = (minorUnits * factor).round();
    return Money.fromMinorUnits(result, currency: currency);
  }

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${other.currency}');
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          minorUnits == other.minorUnits &&
          currency == other.currency;

  @override
  int get hashCode => minorUnits.hashCode ^ currency.hashCode;

  @override
  String toString() => format(this);
}
