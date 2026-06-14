// Uses the same queue-based HttpClientAdapter pattern as account_repository_test.dart.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/core/api/auth_token_store.dart';
import 'package:frontend/features/dashboard/repositories/suggestion_repository.dart';

class _MockTokenStore extends Mock implements AuthTokenStore {}

class _QueueAdapter implements HttpClientAdapter {
  final _queue = <ResponseBody>[];

  void enqueue(int status, Object? body) {
    _queue.add(
      ResponseBody.fromString(
        body != null ? jsonEncode(body) : '',
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
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

Map<String, dynamic> _suggestionResultJson({
  List<Map<String, dynamic>>? allocations,
  double totalAllocated = 500.0,
}) => {
  'allocations':
      allocations ??
      [
        {
          'type': 'goal',
          'id': 'goal-1',
          'name': 'Emergency Fund',
          'amount': 300.0,
          'reason': 'Build safety net',
        },
        {
          'type': 'goal',
          'id': 'goal-2',
          'name': 'Vacation',
          'amount': 200.0,
          'reason': 'Save for trip',
        },
      ],
  'totalAllocated': totalAllocated,
};

void main() {
  late _QueueAdapter adapter;
  late _MockTokenStore tokenStore;
  late ApiClient apiClient;
  late SuggestionRepository repository;

  setUp(() {
    adapter = _QueueAdapter();
    tokenStore = _MockTokenStore();

    when(() => tokenStore.write(any(), any())).thenAnswer((_) async {});
    when(() => tokenStore.readAccess()).thenAnswer((_) async => null);
    when(() => tokenStore.readRefresh()).thenAnswer((_) async => null);
    when(() => tokenStore.clear()).thenAnswer((_) async {});

    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = adapter;

    apiClient = ApiClient(
      dio: dio,
      tokenStore: tokenStore,
      onUnauthenticated: () async {},
    );

    repository = SuggestionRepository(client: apiClient);
  });

  group('SuggestionRepository.getSuggestions', () {
    test(
      'happy path: issues POST /suggestions/generate and returns SuggestionResult',
      () async {
        adapter.enqueue(200, _suggestionResultJson(totalAllocated: 500.0));

        final result = await repository.getSuggestions(excessFunds: 500.0);

        expect(result.totalAllocated, 500.0);
        expect(result.allocations.length, 2);
        expect(result.allocations[0].id, 'goal-1');
        expect(result.allocations[0].name, 'Emergency Fund');
        expect(result.allocations[0].amount, 300.0);
        expect(result.allocations[1].id, 'goal-2');
      },
    );

    test('502 response throws ApiUpstreamException', () async {
      adapter.enqueue(502, {'detail': 'Bad Gateway'});

      expect(
        () => repository.getSuggestions(excessFunds: 250.0),
        throwsA(isA<ApiUpstreamException>()),
      );
    });
  });
}
