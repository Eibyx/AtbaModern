import 'package:atba/config/constants.dart';
import 'package:atba/services/google_drive_session.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Settings.init(cacheProvider: SharePreferenceCache());
  });
  test('secure session survives new store and facade instances', () async {
    final storage = MemorySecureStorage({'api_key': 'torbox-example'});
    final expiry = DateTime.now().add(const Duration(days: 2));
    await TorboxAPI(secureStorageService: storage)
        .saveGoogleToken('google-example', expiry.toIso8601String());
    final restored = TorboxAPI(secureStorageService: storage);
    await restored.init();
    expect(restored.googleToken, 'google-example');
    expect(restored.apiKey, 'torbox-example');
    expect(restored.googleSession!.expiresAt, expiry.toUtc());
    await restored.deleteGoogleToken();
    expect(await GoogleDriveSessionStore(storage).restore(), isNull);
    expect(storage.values['api_key'], 'torbox-example');
  });
  test(
    'legacy token and Settings expiry migrate without reading expiry as token',
    () async {
      final storage = MemorySecureStorage({
        Constants.googleDriveToken: 'legacy-google',
      });
      await Settings.setValue(Constants.googleDriveTokenExpiry, '2000000000');
      final api = TorboxAPI(secureStorageService: storage);
      expect(await api.getGoogleToken(), 'legacy-google');
      expect(
        storage.values.containsKey(GoogleDriveSessionStore.recordKey),
        isTrue,
      );
      expect(storage.values.containsKey(Constants.googleDriveToken), isFalse);
      expect(api.googleSession!.expiresAt!.year, 2033);
    },
  );
  test('expired token is retained securely but cannot be used', () async {
    final storage = MemorySecureStorage();
    final now = DateTime.utc(2026, 10, 19);
    final store = GoogleDriveSessionStore(storage, now: () => now);
    await store.save(
      GoogleDriveSession(
        'expired',
        expiresAt: now.subtract(const Duration(seconds: 1)),
      ),
    );
    expect(await store.usableToken(), isNull);
    expect((await store.restore())!.accessToken, 'expired');
  });
  test(
    'unknown expiration stays unknown, never fabricates a renewed token',
    () async {
      final store = GoogleDriveSessionStore(MemorySecureStorage());
      await store.save(const GoogleDriveSession('manual'));
      expect((await store.restore())!.expiresAt, isNull);
    },
  );
  test(
    'temporary network failure does not disconnect either credential',
    () async {
      final storage = MemorySecureStorage({'api_key': 'torbox-example'});
      final api = TorboxAPI(
        secureStorageService: storage,
        baseUrl: 'http://127.0.0.1:1/v1',
      );
      await api.saveGoogleToken('google-example', '');
      await api.init();
      final response = await api.getUserData();
      expect(response.success, isFalse);
      expect(await api.getGoogleToken(), 'google-example');
      expect(storage.values['api_key'], 'torbox-example');
      api.authenticatedApi?.close();
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
  test('callback requires exact HTTPS origin, route and valid expiry', () {
    expect(
      GoogleDriveSession.fromCallback(
        Uri.parse(
          'https://torbox.app/oauth/google/success?token=example&expires_at=2000000000',
        ),
      ),
      isNotNull,
    );
    for (final url in [
      'http://torbox.app/oauth/google/success?token=x',
      'https://torbox.app.evil.example/oauth/google/success?token=x',
      'https://evil@torbox.app/oauth/google/success?token=x',
      'https://torbox.app:8443/oauth/google/success?token=x',
      'https://torbox.app/oauth/google/success?token=x&expires_at=broken',
    ]) {
      expect(GoogleDriveSession.fromCallback(Uri.parse(url)), isNull);
    }
  });
}
