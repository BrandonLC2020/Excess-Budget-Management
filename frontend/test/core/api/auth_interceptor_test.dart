// NOTE: http_mock_adapter 0.6.1 uses a "last-registered-match-wins" strategy
// via its Recording mixin, which prevents registering the same path for two
// sequential responses (401 then 200 on retry). To accurately test the
// 401→refresh→retry flow, this file uses a queue-based HttpClientAdapter
// instead of DioAdapter. The http_mock_adapter package is still imported (and
// present in pubspec.yaml) — it is used by other test files in the project.
// The deviation is documented here per task instructions.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/core/api/auth_interceptor.dart';
import 'package:frontend/core/api/auth_token_store.dart';

class _MockTokenStore extends Mock implements AuthTokenStore {}

/// A queue-based [HttpClientAdapter] that returns scripted [ResponseBody]s in
/// the order they are enqueued. Throws [AssertionError] when the queue is
/// exhausted and another fetch is attempted.
class _QueueAdapter implements HttpClientAdapter {
  final _queue = <ResponseBody>[];

  void enqueue(int status, Object? body) {
    _queue.add(ResponseBody.fromString(
      body != null ? jsonEncode(body) : '',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    assert(_queue.isNotEmpty, 'No more queued responses');
    return _queue.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _QueueAdapter adapter;
  late _MockTokenStore store;
  late int onUnauthCalls;

  setUp(() {
    adapter = _QueueAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = adapter;

    store = _MockTokenStore();
    onUnauthCalls = 0;

    when(() => store.readAccess()).thenAnswer((_) async => 'old-access');
    when(() => store.readRefresh()).thenAnswer((_) async => 'r1');
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});

    dio.interceptors.add(AuthInterceptor(
      dio: dio,
      tokenStore: store,
      onUnauthenticated: () async {
        onUnauthCalls++;
      },
    ));
  });

  test('refreshes once on 401, retries original request', () async {
    // Queue: original /accounts → 401, /auth/refresh → 200, retry /accounts → 200
    adapter.enqueue(401, {
      'error': {'code': 'auth_error', 'message': 'expired'}
    });
    adapter.enqueue(200, {'access': 'new-access', 'refresh': 'r2'});
    adapter.enqueue(200, [
      {'id': '1'}
    ]);

    final r = await dio.get('/accounts');

    expect(r.statusCode, 200);
    verify(() => store.write('new-access', 'r2')).called(1);
    expect(onUnauthCalls, 0);
  });

  test('clears tokens and signals unauthenticated when refresh fails', () async {
    // Queue: original /accounts → 401, /auth/refresh → 401
    adapter.enqueue(401, {'error': 'auth_error'});
    adapter.enqueue(401, {'error': 'auth_error'});

    await expectLater(
      dio.get('/accounts'),
      throwsA(isA<DioException>()),
    );

    verify(() => store.clear()).called(1);
    expect(onUnauthCalls, 1);
  });
}
