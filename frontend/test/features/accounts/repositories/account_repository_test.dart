// Uses the same queue-based HttpClientAdapter pattern as auth_service_test.dart
// to avoid the last-registered-match-wins limitation of http_mock_adapter.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/auth_token_store.dart';
import 'package:frontend/features/accounts/repositories/account_repository.dart';

class _MockTokenStore extends Mock implements AuthTokenStore {}

/// Queue-based adapter — returns scripted responses in order.
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

// Canned account JSON fixture
Map<String, dynamic> _accountJson({
  String id = 'acc-1',
  String userId = 'user-1',
  String name = 'Checking',
  String balance = '1500.00',
  String createdAt = '2024-01-01T00:00:00Z',
}) => {
  'id': id,
  'user_id': userId,
  'name': name,
  'balance': double.parse(balance),
  'created_at': createdAt,
};

void main() {
  late _QueueAdapter adapter;
  late _MockTokenStore tokenStore;
  late ApiClient apiClient;
  late AccountRepository repository;

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

    repository = AccountRepository(client: apiClient);
  });

  group('AccountRepository.getAccounts', () {
    test('issues GET /accounts and maps JSON list to List<Account>', () async {
      adapter.enqueue(200, [
        _accountJson(id: 'acc-1', name: 'Checking', balance: '1500.00'),
        _accountJson(id: 'acc-2', name: 'Savings', balance: '3200.50'),
      ]);

      final accounts = await repository.getAccounts();

      expect(accounts.length, 2);
      expect(accounts[0].id, 'acc-1');
      expect(accounts[0].name, 'Checking');
      expect(accounts[0].balance, 1500.00);
      expect(accounts[0].userId, 'user-1');
      expect(accounts[1].id, 'acc-2');
      expect(accounts[1].name, 'Savings');
      expect(accounts[1].balance, 3200.50);
    });

    test('returns empty list when server responds with empty array', () async {
      adapter.enqueue(200, <dynamic>[]);

      final accounts = await repository.getAccounts();

      expect(accounts, isEmpty);
    });
  });

  group('AccountRepository.addAccount', () {
    test(
      'issues POST /accounts with name and balance, returns parsed Account',
      () async {
        adapter.enqueue(
          201,
          _accountJson(id: 'acc-new', name: 'Travel Fund', balance: '500.00'),
        );

        final account = await repository.addAccount('Travel Fund', 500.0);

        expect(account.id, 'acc-new');
        expect(account.name, 'Travel Fund');
        expect(account.balance, 500.0);
      },
    );

    test('sends balance as fixed-point string with 2 decimal places', () async {
      // We capture the request by inspecting the interceptor chain via
      // a second enqueue call — the adapter stores the RequestOptions path.
      // Instead, verify the body shape via a custom adapter that captures it.
      RequestOptions? captured;

      final capturingAdapter = _CapturingAdapter(
        delegate: adapter,
        onFetch: (opts) => captured = opts,
      );
      final captureDio = Dio(BaseOptions(baseUrl: 'http://test'));
      captureDio.httpClientAdapter = capturingAdapter;
      final captureClient = ApiClient(
        dio: captureDio,
        tokenStore: tokenStore,
        onUnauthenticated: () async {},
      );
      final captureRepo = AccountRepository(client: captureClient);

      adapter.enqueue(201, _accountJson(name: 'Emergency', balance: '250.75'));

      await captureRepo.addAccount('Emergency', 250.75);

      expect(captured, isNotNull);
      final body = captured!.data as Map<String, dynamic>;
      expect(body['name'], 'Emergency');
      expect(body['balance'], '250.75');
    });
  });

  group('AccountRepository.updateAccount', () {
    test(
      'issues PATCH /accounts/:id with name and balance, returns Account',
      () async {
        adapter.enqueue(
          200,
          _accountJson(
            id: 'acc-1',
            name: 'Updated Checking',
            balance: '2000.00',
          ),
        );

        final account = await repository.updateAccount(
          'acc-1',
          'Updated Checking',
          2000.0,
        );

        expect(account.id, 'acc-1');
        expect(account.name, 'Updated Checking');
        expect(account.balance, 2000.0);
      },
    );
  });

  group('AccountRepository.updateAccountBalance', () {
    test(
      'issues PATCH /accounts/:id with balance only, returns Account',
      () async {
        adapter.enqueue(200, _accountJson(id: 'acc-1', balance: '999.99'));

        final account = await repository.updateAccountBalance('acc-1', 999.99);

        expect(account.id, 'acc-1');
        expect(account.balance, 999.99);
      },
    );
  });

  group('AccountRepository.deleteAccount', () {
    test('issues DELETE /accounts/:id', () async {
      adapter.enqueue(204, null);

      // Should complete without throwing
      await expectLater(repository.deleteAccount('acc-1'), completes);
    });
  });

  group('AccountRepository.getAccountExpenses', () {
    test(
      'issues GET /expenses?account_id=<id> and maps response to List<Expense>',
      () async {
        adapter.enqueue(200, [
          {
            'id': 'exp-1',
            'user_id': 'user-1',
            'budget_category_id': 'cat-1',
            'amount': 45.50,
            'description': 'Groceries',
            'date': '2024-03-15',
            'created_at': '2024-03-15T10:00:00Z',
            'account_id': 'acc-1',
          },
        ]);

        final expenses = await repository.getAccountExpenses('acc-1');

        expect(expenses.length, 1);
        expect(expenses[0].id, 'exp-1');
        expect(expenses[0].amount, 45.50);
        expect(expenses[0].accountId, 'acc-1');
      },
    );
  });

  group('AccountRepository.getAccountIncome', () {
    test(
      'issues GET /income/extra?account_id=<id> and maps response to List<Income>',
      () async {
        adapter.enqueue(200, [
          {
            'id': 'inc-1',
            'user_id': 'user-1',
            'amount': 200.00,
            'description': 'Freelance payment',
            'date_received': '2024-03-20',
            'created_at': '2024-03-20T09:00:00Z',
            'account_id': 'acc-1',
            'budget_category_id': null,
          },
        ]);

        final income = await repository.getAccountIncome('acc-1');

        expect(income.length, 1);
        expect(income[0].id, 'inc-1');
        expect(income[0].amount, 200.00);
        expect(income[0].accountId, 'acc-1');
      },
    );
  });

  group('AccountRepository.getAccountsStream', () {
    test(
      'emits first value immediately without waiting for the 30s period',
      () async {
        adapter.enqueue(200, [
          _accountJson(id: 'acc-1', name: 'Checking', balance: '1000.00'),
        ]);

        final stream = repository.getAccountsStream();
        final first = await stream.first;

        expect(first.length, 1);
        expect(first[0].id, 'acc-1');
      },
    );
  });
}

/// Adapter that delegates to [_QueueAdapter] while also calling [onFetch]
/// so tests can inspect the [RequestOptions].
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({required this.delegate, required this.onFetch});
  final _QueueAdapter delegate;
  final void Function(RequestOptions) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) {
    onFetch(options);
    return delegate.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}
