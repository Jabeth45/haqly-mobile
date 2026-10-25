import 'dart:math';

/// Generates a standard RFC 4122 version 4 UUID in pure Dart.
/// Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx where y is 8, 9, a, or b.
/// Uses [random] if provided (useful for deterministic tests).
String generateUuidV4([Random? random]) {
  final rng = random ?? Random();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
