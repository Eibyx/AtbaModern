import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torbox_api/src/net/interceptors/retry_interceptor.dart';

class FailingAdapter implements HttpClientAdapter {
  int attempts = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    attempts++;
    return ResponseBody.fromString(
      '{"success":false}',
      503,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('POST is never retried after a 503', () async {
    final adapter = FailingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(dio: dio, maxAttempts: 2, baseDelayMs: 1),
    );
    await expectLater(
      dio.post<dynamic>('https://example.test/create'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.attempts, 1);
    dio.close();
  });
  test('GET retries are bounded', () async {
    final adapter = FailingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(dio: dio, maxAttempts: 2, baseDelayMs: 1),
    );
    await expectLater(
      dio.get<dynamic>('https://example.test/list'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.attempts, 3);
    dio.close();
  });
}
