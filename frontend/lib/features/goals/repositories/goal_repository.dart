import 'dart:async';
import 'package:frontend/core/api/api_client.dart';
import '../models/goal.dart';
import '../models/allocation.dart';

class GoalRepository {
  GoalRepository({required this.client});
  final ApiClient client;

  Future<List<Goal>> getGoals() async {
    final r = await client.get<List<dynamic>>('/goals');
    return r.data!
        .map((e) => Goal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Polled replacement for the old Supabase realtime stream.
  /// Emits the current list immediately, then every 30 seconds.
  Stream<List<Goal>> getGoalsStream() async* {
    yield await getGoals();
    yield* Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => getGoals());
  }

  Future<void> addSubGoal(
    String goalId,
    String name,
    double targetAmount,
  ) async {
    await client.post<Map<String, dynamic>>(
      '/goals/$goalId/subgoals',
      body: {
        'name': name,
        'target_amount': targetAmount.toStringAsFixed(2),
      },
    );
  }

  Future<void> updateSubGoalAmount(
    String subGoalId,
    double currentAmount,
  ) async {
    // The backend requires finding the goal_id first. We iterate all goals to
    // locate this sub_goal, then PATCH via /goals/{goal_id}/subgoals/{sid}.
    // If callers already have the goal context, this can be replaced with a
    // direct call to avoid the extra round-trip (tracked as future improvement).
    final goals = await getGoals();
    for (final goal in goals) {
      final sub = goal.subGoals
          .where((s) => s.id == subGoalId)
          .firstOrNull;
      if (sub != null) {
        await client.patch<Map<String, dynamic>>(
          '/goals/${goal.id}/subgoals/$subGoalId',
          body: {'current_amount': currentAmount.toStringAsFixed(2)},
        );
        return;
      }
    }
    throw StateError('Subgoal $subGoalId not found in any goal');
  }

  Future<void> deleteSubGoal(String subGoalId) async {
    // Same lookup pattern as updateSubGoalAmount.
    final goals = await getGoals();
    for (final goal in goals) {
      final found = goal.subGoals.any((s) => s.id == subGoalId);
      if (found) {
        await client.delete<void>('/goals/${goal.id}/subgoals/$subGoalId');
        return;
      }
    }
    throw StateError('Subgoal $subGoalId not found in any goal');
  }

  Future<Goal> addGoal(
    String name,
    double targetAmount,
    String type, {
    String category = 'savings',
    DateTime? targetDate,
    List<String> accountIds = const [],
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'target_amount': targetAmount.toStringAsFixed(2),
      'type': type,
      'category': category,
    };
    if (targetDate != null) {
      body['target_date'] = targetDate.toIso8601String().split('T').first;
    }

    final r = await client.post<Map<String, dynamic>>('/goals', body: body);
    final goal = Goal.fromJson(r.data!);

    // Link each account separately
    for (final accountId in accountIds) {
      await linkAccountToGoal(goal.id, accountId);
    }

    return goal;
  }

  Future<void> linkAccountToGoal(String goalId, String accountId) async {
    await client.post<Map<String, dynamic>>(
      '/goals/$goalId/accounts',
      body: {'account_id': accountId},
    );
  }

  Future<void> updateGoalAccounts(String goalId, List<String> accountIds) async {
    // 1. Fetch current linked accounts
    final goals = await getGoals();
    final goal = goals.firstWhere((g) => g.id == goalId,
        orElse: () => throw StateError('Goal $goalId not found'));

    // 2. Unlink all current accounts
    for (final accId in goal.accountIds) {
      await client.delete<void>('/goals/$goalId/accounts/$accId');
    }

    // 3. Link new accounts
    for (final accId in accountIds) {
      await linkAccountToGoal(goalId, accId);
    }
  }

  Future<void> insertAllocation(
    String goalId,
    double amount, {
    String? accountId,
    String? subGoalId,
  }) async {
    final body = <String, dynamic>{
      'goal_id': goalId,
      'amount': amount.toStringAsFixed(2),
    };
    if (accountId != null) body['account_id'] = accountId;
    if (subGoalId != null) body['sub_goal_id'] = subGoalId;

    await client.post<Map<String, dynamic>>('/allocations', body: body);
  }

  Future<List<GoalAllocation>> getAllocations() async {
    final r = await client.get<List<dynamic>>('/allocations');
    return r.data!
        .map((e) => GoalAllocation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, double>> getRecentAllocationSummary(int days) async {
    final r = await client.get<Map<String, dynamic>>(
      '/allocations/summary',
      query: {'days': days.toString()},
    );
    final data = r.data!;
    return {
      'totalSavings': (data['totalSavings'] as num).toDouble(),
      'totalPurchases': (data['totalPurchases'] as num).toDouble(),
    };
  }

  /// In the Django backend, current_amount is managed by DB signals triggered
  /// by allocation creation/deletion. Calling this will re-fetch the goal to
  /// return its latest state. The [currentAmount] parameter is ignored.
  Future<Goal> updateGoalCurrentAmount(String id, double currentAmount) async {
    final r = await client.get<Map<String, dynamic>>('/goals/$id');
    return Goal.fromJson(r.data!);
  }

  Future<void> deleteGoal(String id) =>
      client.delete<void>('/goals/$id');

  Future<List<Goal>> getSubgoals(String goalId) async {
    // The backend returns subgoals nested in goal; we can also GET them directly.
    final r = await client.get<List<dynamic>>('/goals/$goalId/subgoals');
    // Subgoals come back as SubgoalOut — wrap them as a minimal Goal proxy
    // by re-fetching the parent goal. For most use cases callers just need the
    // subgoals list from the Goal object itself, so we re-fetch:
    final goals = await getGoals();
    final goal = goals.firstWhere((g) => g.id == goalId,
        orElse: () => throw StateError('Goal $goalId not found'));
    return [goal]; // Returns parent with nested subGoals
  }
}
