import 'dart:convert';

/// Deterministic FNV-1a 32-bit hash and avatar initials extractor.
/// Follows docs/DOMAIN_SPEC.md Section 10.
/// Pure Dart (no Flutter or platform dependencies).

const int _fnvOffsetBasis32 = 0x811c9dc5;
const int _fnvPrime32 = 0x01000193;

/// Computes a stable, cross-platform 32-bit FNV-1a hash over UTF-8 bytes.
/// Standard `String.hashCode` is NOT used because it is not guaranteed stable across Dart runtimes.
int fnv1a32(String input) {
  final bytes = utf8.encode(input.trim().toLowerCase());
  var hash = _fnvOffsetBasis32;

  for (final b in bytes) {
    hash ^= b;
    hash = (hash * _fnvPrime32) & 0xFFFFFFFF;
  }

  return hash;
}

/// Returns a stable palette index between 0 and [paletteLength - 1] for a given name.
int getAvatarColorIndex(String name, int paletteLength) {
  if (paletteLength <= 1) return 0;
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 0;

  final hash = fnv1a32(trimmed);
  return hash % paletteLength;
}

/// Extracts 1 or 2 initials from a person's name (supports English and Amharic).
/// Examples:
///   "Abebe Kebede" -> "AK"
///   "Almaz" -> "A"
///   "አበባ ከበደ" -> "አከ"
String extractInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';

  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';

  if (parts.length == 1) {
    final runes = parts[0].runes.toList();
    if (runes.isEmpty) return '?';
    return String.fromCharCode(runes[0]).toUpperCase();
  }

  final firstRune = parts.first.runes.first;
  final lastRune = parts.last.runes.first;

  return '${String.fromCharCode(firstRune)}${String.fromCharCode(lastRune)}'
      .toUpperCase();
}
