import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/data/remote/secure_local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK-032: SecureLocalStorage & Security S-01', () {
    late SecureLocalStorage storage;
    const testSession = '{"access_token":"mock_jwt_token","user_id":"u-123"}';

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      storage = SecureLocalStorage();
    });

    test('initial state has no access token', () async {
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    });

    test(
      'persistSession securely stores token in FlutterSecureStorage',
      () async {
        await storage.persistSession(testSession);

        expect(await storage.hasAccessToken(), isTrue);
        expect(await storage.accessToken(), testSession);

        // Verify directly from secure storage
        const secureStorage = FlutterSecureStorage();
        final directValue = await secureStorage.read(
          key: SecureLocalStorage.defaultSessionKey,
        );
        expect(directValue, testSession);
      },
    );

    test(
      'session is stored in secure storage and NOT in SharedPreferences (S-01)',
      () async {
        await storage.persistSession(testSession);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.containsKey(SecureLocalStorage.defaultSessionKey),
          isFalse,
        );
        expect(prefs.getKeys().isEmpty, isTrue);
      },
    );

    test(
      'removePersistedSession removes session from secure storage',
      () async {
        await storage.persistSession(testSession);
        expect(await storage.hasAccessToken(), isTrue);

        await storage.removePersistedSession();
        expect(await storage.hasAccessToken(), isFalse);
        expect(await storage.accessToken(), isNull);
      },
    );
  });

  group('TASK-032: SecureGotrueAsyncStorage (PKCE verifier)', () {
    late SecureGotrueAsyncStorage pkceStorage;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      pkceStorage = SecureGotrueAsyncStorage();
    });

    test(
      'setItem, getItem, and removeItem manage keys in secure storage',
      () async {
        expect(await pkceStorage.getItem(key: 'pkce_verifier'), isNull);

        await pkceStorage.setItem(
          key: 'pkce_verifier',
          value: 'code_challenge_123',
        );
        expect(
          await pkceStorage.getItem(key: 'pkce_verifier'),
          'code_challenge_123',
        );

        await pkceStorage.removeItem(key: 'pkce_verifier');
        expect(await pkceStorage.getItem(key: 'pkce_verifier'), isNull);
      },
    );
  });
}
