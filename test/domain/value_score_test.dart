import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/domain/value_score.dart';

void main() {
  group('calcValueScore - Domain Vector Parity', () {
    test('matches all cases in docs/test_vectors/domain_vectors.json', () {
      final file = File('docs/test_vectors/domain_vectors.json');
      expect(file.existsSync(), isTrue);

      final jsonContent =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final cases = (jsonContent['calcValueScore'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      for (final c in cases) {
        final verdicts = (c['verdicts'] as List<dynamic>).cast<String>();
        final expectedScore = c['score'] as int;
        final expectedWorthPct = c['worthPct'] as int;
        final expectedMaybePct = c['maybePct'] as int;
        final expectedNotPct = c['notPct'] as int;
        final expectedLabel = c['label'] as String;

        final actual = calcValueScore(verdicts);
        expect(
          actual,
          isNotNull,
          reason: 'Result should not be null for non-empty input',
        );

        expect(
          actual!.score,
          equals(expectedScore),
          reason: 'Score mismatch for verdicts: $verdicts',
        );
        expect(
          actual.worthPct,
          equals(expectedWorthPct),
          reason: 'WorthPct mismatch for verdicts: $verdicts',
        );
        expect(
          actual.maybePct,
          equals(expectedMaybePct),
          reason: 'MaybePct mismatch for verdicts: $verdicts',
        );
        expect(
          actual.notPct,
          equals(expectedNotPct),
          reason: 'NotPct mismatch for verdicts: $verdicts',
        );
        expect(
          actual.label.text,
          equals(expectedLabel),
          reason: 'Label mismatch for verdicts: $verdicts',
        );
      }
    });

    test('empty verdicts list returns null per DOMAIN_SPEC Section 3', () {
      expect(calcValueScore([]), isNull);
    });

    test('label boundaries match DOMAIN_SPEC exactly', () {
      expect(
        ValueScoreLabel.fromScore(100),
        equals(ValueScoreLabel.smartSpender),
      );
      expect(
        ValueScoreLabel.fromScore(75),
        equals(ValueScoreLabel.smartSpender),
      );
      expect(ValueScoreLabel.fromScore(74), equals(ValueScoreLabel.onTrack));
      expect(ValueScoreLabel.fromScore(50), equals(ValueScoreLabel.onTrack));
      expect(
        ValueScoreLabel.fromScore(49),
        equals(ValueScoreLabel.needsAttention),
      );
      expect(
        ValueScoreLabel.fromScore(25),
        equals(ValueScoreLabel.needsAttention),
      );
      expect(
        ValueScoreLabel.fromScore(24),
        equals(ValueScoreLabel.reviewSpending),
      );
      expect(
        ValueScoreLabel.fromScore(0),
        equals(ValueScoreLabel.reviewSpending),
      );
    });
  });
}
