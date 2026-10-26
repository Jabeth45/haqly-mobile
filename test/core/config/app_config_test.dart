import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/config/app_config.dart';

void main() {
  group('TASK-032: AppConfig Environment Defines', () {
    test('default environment fallback is dev', () {
      expect(AppConfig.appEnv, 'dev');
    });

    test(
      'isConfigured returns false when URL and key are empty or placeholders',
      () {
        // In default headless test environment without dart-define, isConfigured is false
        expect(AppConfig.isConfigured, isFalse);
      },
    );
  });
}
