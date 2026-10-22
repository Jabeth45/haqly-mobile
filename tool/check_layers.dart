import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib directory does not exist.');
    exit(1);
  }

  final violations = <String>[];
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final normalizedPath = file.path.replaceAll(r'\', '/');
    if (normalizedPath.contains('/generated/') ||
        normalizedPath.endsWith('.g.dart') ||
        normalizedPath.endsWith('.drift.dart')) {
      continue;
    }
    final lines = file.readAsLinesSync();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNum = i + 1;

      // Rule: No print() in lib/
      if (line.contains(RegExp(r'\bprint\s*\(')) &&
          !line.trim().startsWith('//')) {
        violations.add(
          '$normalizedPath:$lineNum: Forbidden print() statement. Use logger wrapper.',
        );
      }

      // Rule: No Color(0x outside lib/core/theme/tokens.dart
      if (line.contains('Color(0x') &&
          !normalizedPath.endsWith('tokens.dart') &&
          !line.trim().startsWith('//')) {
        violations.add(
          '$normalizedPath:$lineNum: Forbidden Color(0x outside core/theme/tokens.dart.',
        );
      }

      // Rule: lib/domain/ must be pure Dart
      if (normalizedPath.contains('lib/domain/')) {
        if (line.contains("import 'package:flutter") ||
            line.contains('import "package:flutter') ||
            line.contains("import 'package:drift") ||
            line.contains('import "package:drift') ||
            line.contains("import 'package:supabase") ||
            line.contains('import "package:supabase')) {
          violations.add(
            '$normalizedPath:$lineNum: Domain layer violation: pure Dart only, no Flutter/Drift/Supabase.',
          );
        }
      }

      // Rule: features/ and shared/ must not import data internals or supabase
      if (normalizedPath.contains('lib/features/') ||
          normalizedPath.contains('lib/shared/')) {
        if (line.contains('data/db') ||
            line.contains('data/sync') ||
            line.contains('data/remote') ||
            line.contains('package:supabase')) {
          violations.add(
            '$normalizedPath:$lineNum: UI layer violation: features/ and shared/ must not import data/db, data/sync, data/remote, or supabase.',
          );
        }
      }

      // Rule: Only data/sync and data/remote may import supabase
      if (!normalizedPath.contains('lib/data/sync/') &&
          !normalizedPath.contains('lib/data/remote/')) {
        if (line.contains('package:supabase_flutter') ||
            line.contains('package:supabase/')) {
          violations.add(
            '$normalizedPath:$lineNum: Supabase import forbidden outside data/sync/ and data/remote/.',
          );
        }
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln(
      'Layer check FAILED with ${violations.length} violation(s):',
    );
    for (final v in violations) {
      stderr.writeln('  [VIOLATION] $v');
    }
    exit(1);
  }

  stdout.writeln('Layer check PASSED cleanly. Zero architectural violations.');
}
