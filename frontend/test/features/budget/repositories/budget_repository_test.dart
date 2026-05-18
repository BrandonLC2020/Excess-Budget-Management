// Uses the same queue-based HttpClientAdapter pattern as account_repository_test.dart.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/auth_token_store.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';
import 'package:frontend/features/budget/models/budget_category.dart';

class _MockTokenStore extends Mock implements AuthTokenStore {}

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

Map<String, dynamic> _categoryJson({
  String id = 'cat-1',
  String userId = 'user-1',
  String name = 'Groceries',
  String limitAmount = '300.00',
  String spentAmount = '0.00',
  String categoryType = 'expense',
  String createdAt = '2024-01-01T00:00:00Z',
}) =>
    {
      'id': id,
      'user_id': userId,
      'name': name,
      'limit_amount': double.parse(limitAmount),
      'spent_amount': double.parse(spentAmount),
      'category_type': categoryType,
      'icon_code': null,
      'color_hex': null,
      'created_at': createdAt,
    };

Map<String, dynamic> _expenseJson({
  String id = 'exp-1',
  String userId = 'user-1',
  String budgetCategoryId = 'cat-1',
  double amount = 45.0,
  String date = '2024-03-15',
  String createdAt = '2024-03-15T10:00:00Z',
}) =>
    {
      'id': id,
      'user_id': userId,
      'budget_category_id': budgetCategoryId,
      'amount': amount,
      'description': null,
      'date': date,
      'created_at': createdAt,
      'account_id': null,
    };

void main() {
  late _QueueAdapter adapter;
  late _MockTokenStore tokenStore;
  late ApiClient apiClient;
  late BudgetRepository repository;

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

    repository = BudgetRepository(client: apiClient);
  });

  group('BudgetRepository.getBudgetCategories', () {
    test('issues GET /budget/categories and maps to List<BudgetCategory>', () async {
      adapter.enqueue(200, [
        _categoryJson(id: 'cat-1', name: 'Groceries', limitAmount: '300.00'),
        _categoryJson(id: 'cat-2', name: 'Transport', limitAmount: '100.00',
            categoryType: 'expense'),
      ]);

      final categories = await repository.getBudgetCategories();

      expect(categories.length, 2);
      expect(categories[0].id, 'cat-1');
      expect(categories[0].name, 'Groceries');
      expect(categories[0].limitAmount, 300.0);
      expect(categories[0].type, BudgetCategoryType.expense);
      expect(categories[1].id, 'cat-2');
    });

    test('returns empty list when server responds with empty array', () async {
      adapter.enqueue(200, <dynamic>[]);

      final categories = await repository.getBudgetCategories();

      expect(categories, isEmpty);
    });
  });

  group('BudgetRepository.addBudgetCategory', () {
    test('issues POST /budget/categories and returns parsed BudgetCategory', () async {
      adapter.enqueue(201, _categoryJson(
        id: 'cat-new',
        name: 'Entertainment',
        limitAmount: '150.00',
        categoryType: 'expense',
      ));

      final category = await repository.addBudgetCategory(
        'Entertainment',
        150.0,
        type: BudgetCategoryType.expense,
      );

      expect(category.id, 'cat-new');
      expect(category.name, 'Entertainment');
      expect(category.limitAmount, 150.0);
      expect(category.type, BudgetCategoryType.expense);
    });

    test('sends limit_amount as fixed-point string with 2 decimal places', () async {
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
      final captureRepo = BudgetRepository(client: captureClient);

      adapter.enqueue(201, _categoryJson(name: 'Bills', limitAmount: '299.99'));

      await captureRepo.addBudgetCategory('Bills', 299.99);

      expect(captured, isNotNull);
      final body = captured!.data as Map<String, dynamic>;
      expect(body['name'], 'Bills');
      expect(body['limit_amount'], '299.99');
      expect(body['category_type'], 'expense');
    });
  });

  group('BudgetRepository.getCategoryExpenses', () {
    test('issues GET /expenses?budget_category_id=<id> and maps to List<Expense>', () async {
      adapter.enqueue(200, [
        _expenseJson(id: 'exp-1', budgetCategoryId: 'cat-1', amount: 45.0),
        _expenseJson(id: 'exp-2', budgetCategoryId: 'cat-1', amount: 20.0),
      ]);

      final expenses = await repository.getCategoryExpenses('cat-1');

      expect(expenses.length, 2);
      expect(expenses[0].id, 'exp-1');
      expect(expenses[0].amount, 45.0);
      expect(expenses[0].budgetCategoryId, 'cat-1');
      expect(expenses[1].amount, 20.0);
    });
  });
}

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
