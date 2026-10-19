import 'package:atba/screens/modern/remote_settings_page.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:torbox_api/torbox_api.dart';

import '../support/fakes.dart';

void main() {
  testWidgets(
    'loads current settings before sending a non-null partial change',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final api = TorboxAPI(
        secureStorageService: MemorySecureStorage(),
        apiKey: 'example-only',
        apiFactory: (token) {
          final client = TorboxApi(token: token, maxAttempts: 0);
          client.addInterceptor(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.method == 'PUT') {
                  writes.add(Map<String, dynamic>.from(options.data as Map));
                }
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      'success': true,
                      'error': null,
                      'detail': '',
                      'data': options.method == 'PUT'
                          ? null
                          : {
                              'id': 1,
                              'auth_id': 'example',
                              'settings': {
                                'email_notifications': false,
                                'web_notifications': true,
                                'mobile_notifications': false,
                                'rss_notifications': false,
                                'allow_zipped': true,
                                'append_filename_to_links': true,
                                'cdn_selection': 'auto',
                                'google_drive_folder_id': 'example-folder',
                                'seed_torrents': 1,
                              },
                            },
                    },
                  ),
                );
              },
            ),
          );
          return client;
        },
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: api,
          child: const MaterialApp(home: RemoteSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Correo electrónico'), findsOneWidget);
      await tester.tap(find.text('Correo electrónico'));
      await tester.pump();
      final save = find.text('Guardar cambios');
      await tester.scrollUntilVisible(
        save,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(writes, [
        {'email_notifications': true},
      ]);
      await tester.pumpWidget(const SizedBox());
      api.authenticatedApi?.close();
    },
  );
}
