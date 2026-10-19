import 'dart:async';

import 'package:atba/services/adaptive_poller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active progress refreshes every six seconds without overlapping', () {
    fakeAsync((clock) {
      var calls = 0;
      final pending = Completer<bool>();
      final poller = AdaptivePoller(
        poll: () {
          calls++;
          return calls == 1 ? pending.future : Future.value(true);
        },
      );
      poller.start();
      poller.refresh();
      clock.elapse(const Duration(minutes: 1));
      expect(calls, 1);
      pending.complete(true);
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 6));
      expect(calls, 2);
      poller.dispose();
      clock.elapse(const Duration(minutes: 5));
      expect(calls, 2);
    });
  });
  test('transient failures back off and recover automatically', () {
    fakeAsync((clock) {
      var calls = 0;
      final poller = AdaptivePoller(
        poll: () async {
          calls++;
          if (calls <= 2) throw StateError('503');
          return true;
        },
      );
      poller.start();
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 8));
      expect(calls, 2);
      clock.elapse(const Duration(seconds: 16));
      expect(calls, 3);
      clock.elapse(const Duration(seconds: 6));
      expect(calls, 4);
      poller.dispose();
    });
  });
  test('background pauses queries and resume refreshes immediately', () {
    fakeAsync((clock) {
      var calls = 0;
      final poller = AdaptivePoller(
        poll: () async {
          calls++;
          return false;
        },
      );
      poller.start();
      clock.flushMicrotasks();
      poller.pause();
      clock.elapse(const Duration(minutes: 10));
      expect(calls, 1);
      poller.start();
      clock.flushMicrotasks();
      expect(calls, 2);
      clock.elapse(const Duration(seconds: 30));
      expect(calls, 3);
      poller.dispose();
    });
  });
}
