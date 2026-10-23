import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/domain/uuid_utils.dart';

void main() {
  group('uuid_utils - RFC 4122 v4 Generator', () {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('generates valid RFC 4122 version 4 UUIDs', () {
      for (var i = 0; i < 100; i++) {
        final uuid = generateUuidV4();
        expect(
          uuidRegex.hasMatch(uuid),
          isTrue,
          reason: 'Generated UUID $uuid does not conform to v4 RFC 4122',
        );
      }
    });

    test('generates distinct UUIDs on successive calls', () {
      final set = <String>{};
      for (var i = 0; i < 1000; i++) {
        final uuid = generateUuidV4();
        expect(set.add(uuid), isTrue, reason: 'Duplicate UUID generated');
      }
    });

    test('produces deterministic output given seeded Random', () {
      final uuid1 = generateUuidV4(Random(42));
      final uuid2 = generateUuidV4(Random(42));
      expect(uuid1, equals(uuid2));
      expect(uuidRegex.hasMatch(uuid1), isTrue);
    });
  });
}
