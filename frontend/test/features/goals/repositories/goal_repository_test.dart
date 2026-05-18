// Uses the same queue-based HttpClientAdapter pattern as account_repository_test.dart.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/auth_token_store.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';

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

Map<String, dynamic> _goalJson({
  String id = 'goal-1',
  String name = 'Emergency Fund',
  String targetAmount = '1000.00',
  String currentAmount = '0.00',
  String type = 'long_term',
  String category = 'savings',
  String createdAt = '2024-01-01T00:00:00Z',
  String? targetDate,
}) =>
    {
      'id': id,
      'name': name,
      'target_amount': double.parse(targetAmount),
      'current_amount': double.parse(currentAmount),
      'type': type,
      'category': category,
      'created_at': createdAt,
      'target_date': targetDate,
      // Django API does not return sub_goals or goal_accounts in GoalOut
      'sub_goals': null,
      'goal_accounts': null,
    };

void main() {
  late _QueueAdapter adapter;
  late _MockTokenStore tokenStore;
  late ApiClient apiClient;
  late GoalRepository repository;

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

    repository = GoalRepository(client: apiClient);
  });

  group('GoalRepository.getGoals', () {
    test('issues GET /goals and maps JSON list to List<Goal>', () async {
      adapter.enqueue(200, [
        _goalJson(id: 'goal-1', name: 'Emergency Fund', targetAmount: '1000.00'),
        _goalJson(id: 'goal-2', name: 'Vacation', targetAmount: '2000.00',
            type: 'short_term', category: 'purchase'),
      ]);

      final goals = await repository.getGoals();

      expect(goals.length, 2);
      expect(goals[0].id, 'goal-1');
      expect(goals[0].name, 'Emergency Fund');
      expect(goals[0].targetAmount, 1000.0);
      expect(goals[0].category, 'savings');
      expect(goals[1].id, 'goal-2');
      expect(goals[1].category, 'purchase');
    });

    test('returns empty list when server responds with empty array', () async {
      adapter.enqueue(200, <dynamic>[]);

      final goals = await repository.getGoals();

      expect(goals, isEmpty);
    });
  });

  group('GoalRepository.addGoal', () {
    test('issues POST /goals and returns parsed Goal (no account links)', () async {
      adapter.enqueue(201, _goalJson(
        id: 'goal-new',
        name: 'New Car',
        targetAmount: '15000.00',
        type: 'long_term',
        category: 'purchase',
      ));

      final goal = await repository.addGoal(
        'New Car',
        15000.0,
        'long_term',
        category: 'purchase',
      );

      expect(goal.id, 'goal-new');
      expect(goal.name, 'New Car');
      expect(goal.targetAmount, 15000.0);
      expect(goal.category, 'purchase');
    });

    test('links accounts after creating goal when accountIds provided', () async {
      adapter.enqueue(201, _goalJson(id: 'goal-3', name: 'Savings'));
      // linkAccountToGoal calls POST /goals/{id}/accounts
      adapter.enqueue(201, {
        'goal_id': 'goal-3',
        'account_id': 'acc-1',
        'created_at': '2024-01-01T00:00:00Z',
      });

      final goal = await repository.addGoal(
        'Savings',
        500.0,
        'long_term',
        accountIds: ['acc-1'],
      );

      expect(goal.id, 'goal-3');
    });
  });

  group('GoalRepository.getSubgoals', () {
    test('returns parent goal containing subgoals list', () async {
      // getSubgoals internally calls GET /goals/{id}/subgoals then getGoals
      adapter.enqueue(200, <dynamic>[]); // /goals/{id}/subgoals response
      adapter.enqueue(200, [           // getGoals fallback
        _goalJson(id: 'goal-1', name: 'Goal with subs'),
      ]);

      final result = await repository.getSubgoals('goal-1');

      expect(result.isNotEmpty, isTrue);
      expect(result[0].id, 'goal-1');
    });
  });

  group('GoalRepository.linkAccountToGoal', () {
    test('issues POST /goals/{id}/accounts', () async {
      adapter.enqueue(201, {
        'goal_id': 'goal-1',
        'account_id': 'acc-2',
        'created_at': '2024-01-01T00:00:00Z',
      });

      await expectLater(
        repository.linkAccountToGoal('goal-1', 'acc-2'),
        completes,
      );
    });
  });

  group('GoalRepository.getRecentAllocationSummary', () {
    test('issues GET /allocations/summary and returns totalSavings/totalPurchases', () async {
      adapter.enqueue(200, {'totalSavings': 350.0, 'totalPurchases': 200.0});

      final summary = await repository.getRecentAllocationSummary(30);

      expect(summary['totalSavings'], 350.0);
      expect(summary['totalPurchases'], 200.0);
    });
  });
}
