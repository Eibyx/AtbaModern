import 'package:atba/models/library_items/webdownload.dart';
import 'package:atba/services/local_event_notifier.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('atba.modern/test-notifications');
  test(
    'only new terminal transitions notify, never initial or repeated snapshots',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      final notifier = LocalEventNotifier(
        channel: channel,
        supported: true,
        enabled: () => true,
      );
      final active = WebDownload.fromJson(transferJson());
      final done = WebDownload.fromJson(transferJson(progress: 1));
      await notifier.transfers([], [done]);
      expect(calls, isEmpty);
      await notifier.transfers([active], [done]);
      expect(calls.length, 1);
      expect(
        (calls.single.arguments as Map)['title'],
        'TorBox · Descarga completada',
      );
      await notifier.transfers([done], [done]);
      expect(calls.length, 1);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
}
