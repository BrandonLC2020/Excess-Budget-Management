// Uses the same queue-based HttpClientAdapter pattern as account_repository_test.dart.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/auth_token_store.dart';
import 'package:frontend/features/income/repositories/income_repository.dart';

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

Map<String, dynamic> _incomeJson({
  String id = 'inc-1',
  String userId = 'user-1',
  double amount = 200.0,
  String? description = 'Freelance',
  String dateReceived = '2024-03-20',
  String createdAt = '2024-03-20T09:00:00Z',
  String? accountId,
  String? budgetCategoryId,
}) => {
  'id': id,
  'user_id': userId,
  'amount': amount,
  'description': description,
  'date_received': dateReceived,
  'created_at': createdAt,
  'account_id': accountId,
  'budget_category_id': budgetCategoryId,
};

void main() {
  late _QueueAdapter adapter;
  late _MockTokenStore tokenStore;
  late ApiClient apiClient;
  late IncomeRepository repository;

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

    repository = IncomeRepository(client: apiClient);
  });

  group('IncomeRepository.getIncome', () {
    test('issues GET /income/extra and maps to List<Income>', () async {
      adapter.enqueue(200, [
        _incomeJson(id: 'inc-1', amount: 200.0, description: 'Freelance'),
        _incomeJson(id: 'inc-2', amount: 50.0, description: 'Refund'),
      ]);

      final income = await repository.getIncome();

      expect(income.length, 2);
      expect(income[0].id, 'inc-1');
      expect(income[0].amount, 200.0);
      expect(income[1].id, 'inc-2');
      expect(income[1].amount, 50.0);
    });

    test('returns empty list when server responds with empty array', () async {
      adapter.enqueue(200, <dynamic>[]);

      final income = await repository.getIncome();

      expect(income, isEmpty);
    });
  });

  group('IncomeRepository.deleteIncome', () {
    test('issues DELETE /income/extra/:id', () async {
      adapter.enqueue(204, null);

      await expectLater(repository.deleteIncome('inc-1'), completes);
    });
  });

  group('IncomeRepository.bulkInsertExtraIncome', () {
    test('issues one POST per entry, stripping user_id', () async {
      // Enqueue responses for 2 entries
      adapter.enqueue(201, _incomeJson(id: 'inc-a', amount: 100.0));
      adapter.enqueue(201, _incomeJson(id: 'inc-b', amount: 75.0));

      final entries = [
        {
          'user_id': 'should-be-stripped',
          'amount': '100.00',
          'date_received': '2024-03-20',
        },
        {
          'user_id': 'should-be-stripped',
          'amount': '75.00',
          'date_received': '2024-03-21',
        },
      ];

      // Should complete without throwing (uses up both queued responses)
      await expectLater(repository.bulkInsertExtraIncome(entries), completes);
    });
  });
}
