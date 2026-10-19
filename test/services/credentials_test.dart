import 'package:atba/services/torbox_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torbox_api/torbox_api.dart';

import '../support/fakes.dart';

void main() {
  test('rejected replacement preserves stored and active TorBox and Google credentials', () async {
    final storage = MemorySecureStorage({'api_key': 'old-example'});
    final requests = <String>[];
    TorboxApi factory(String token) {
      final client = TorboxApi(token: token, maxAttempts: 0);
      client.addInterceptor(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request.path);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'success': token == 'accepted-example',
                  'error': null,
                  'detail': '',
                  'data': token == 'accepted-example'
                      ? {'id': 1, 'auth_id': 'example'}
                      : null,
                },
              ),
            );
          },
        ),
      );
      return client;
    }

    final api = TorboxAPI(
      secureStorageService: storage,
      apiKey: 'old-example',
      apiFactory: factory,
    );
    await api.saveGoogleToken('google-example', '');
    expect(
      (await api.validateAndSaveApiKey('rejected-example')).success,
      isFalse,
    );
    expect(api.apiKey, 'old-example');
    expect(storage.values['api_key'], 'old-example');
    expect(await api.getGoogleToken(), 'google-example');
    expect(
      (await api.validateAndSaveApiKey(' accepted-example ')).success,
      isTrue,
    );
    expect(storage.values['api_key'], 'accepted-example');
    expect(api.apiKey, 'accepted-example');
    expect(requests, everyElement('api/user/me'));
    expect(requests.length, 2); // No referrals or extra account mutations.
    api.authenticatedApi?.close();
  });
  test('empty replacement performs no network or storage changes', () async {
    final storage = MemorySecureStorage({'api_key': 'old-example'});
    final api = TorboxAPI(secureStorageService: storage, apiKey: 'old-example');
    expect((await api.validateAndSaveApiKey('  ')).success, isFalse);
    expect(storage.values['api_key'], 'old-example');
    api.authenticatedApi?.close();
  });
}
