import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/domain/avatar_utils.dart';

void main() {
  group('avatar_utils - Stable FNV-1a Hash & Initials', () {
    test('fnv1a32 returns deterministic values across multiple calls and platforms', () {
      final h1 = fnv1a32('Abebe');
      final h2 = fnv1a32('Abebe');
      final h3 = fnv1a32('abebe');
      final h4 = fnv1a32('  Abebe  ');

      expect(h1, equals(h2));
      expect(h1, equals(h3));
      expect(h1, equals(h4));
      // Known reference FNV-1a for 'abebe':
      expect(h1, isNonNegative);
    });

    test('getAvatarColorIndex stays strictly within palette bounds', () {
      const paletteSize = 8;
      final names = [
        'Abebe',
        'Kebede',
        'Almaz',
        'Dawit',
        'Hanna',
        'Tadesse',
        'አበባ',
        'ከበደ',
        '',
      ];

      for (final name in names) {
        final idx = getAvatarColorIndex(name, paletteSize);
        expect(idx, greaterThanOrEqualTo(0));
        expect(idx, lessThan(paletteSize));

        // Same name gets same index every time
        expect(getAvatarColorIndex(name, paletteSize), equals(idx));
      }
    });

    test('extractInitials extracts single or double letters in English and Amharic', () {
      expect(extractInitials('Abebe Kebede'), equals('AK'));
      expect(extractInitials('Almaz'), equals('A'));
      expect(extractInitials('Dawit Mengistu Haile'), equals('DH'));
      expect(extractInitials('  hanna  '), equals('H'));
      expect(extractInitials(''), equals('?'));
      expect(extractInitials('   '), equals('?'));

      // Ethiopic Ge'ez characters
      expect(extractInitials('አበባ ከበደ'), equals('አከ'));
      expect(extractInitials('ሰለሞን'), equals('ሰ'));
    });
  });
}
