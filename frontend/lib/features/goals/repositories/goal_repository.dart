import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/goal.dart';
import '../models/allocation.dart';

class GoalRepository {
  final SupabaseClient supabase;

  GoalRepository({required this.supabase});

  Future<List<Goal>> getGoals() async {
    final response = await supabase
        .from('goals')
        .select('*, sub_goals(*)')
        .order('created_at', ascending: true);
    return (response as List).map((e) => Goal.fromJson(e)).toList();
  }

  Future<void> addSubGoal(
    String goalId,
    String name,
    double targetAmount,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await supabase.from('sub_goals').insert({
      'user_id': userId,
      'goal_id': goalId,
      'name': name,
      'target_amount': targetAmount,
    });
  }

  Future<void> updateSubGoalAmount(
    String subGoalId,
    double currentAmount,
  ) async {
    await supabase
        .from('sub_goals')
        .update({'current_amount': currentAmount})
        .eq('id', subGoalId);
  }

  Future<void> deleteSubGoal(String subGoalId) async {
    await supabase.from('sub_goals').delete().eq('id', subGoalId);
  }

  Future<Goal> addGoal(
    String name,
    double targetAmount,
    String type, {
    String category = 'savings',
    DateTime? targetDate,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final response = await supabase
        .from('goals')
        .insert({
          'user_id': userId,
          'name': name,
          'target_amount': targetAmount,
          'type': type,
          'category': category,
          if (targetDate != null) 'target_date': targetDate.toIso8601String(),
        })
        .select()
        .single();

    return Goal.fromJson(response);
  }

  Future<void> insertAllocation(
    String goalId,
    double amount, {
    String? accountId,
    String? subGoalId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await supabase.from('goal_allocations').insert({
      'user_id': userId,
      'goal_id': goalId,
      'amount': amount,
      'account_id': accountId,
      'sub_goal_id': subGoalId,
    });
  }

  Future<List<GoalAllocation>> getAllocations() async {
    final response = await supabase
        .from('goal_allocations')
        .select('*, goals(name), accounts(name)')
        .order('created_at', ascending: false);
    return (response as List).map((e) => GoalAllocation.fromJson(e)).toList();
  }

  Future<Map<String, double>> getRecentAllocationSummary(int days) async {
    final response = await supabase.rpc(
      'get_recent_allocation_summary',
      params: {'days': days},
    );

    final data = response as Map<String, dynamic>;
    return {
      'totalSavings': (data['totalSavings'] as num).toDouble(),
      'totalPurchases': (data['totalPurchases'] as num).toDouble(),
    };
  }

  Future<Goal> updateGoalCurrentAmount(String id, double currentAmount) async {
    final response = await supabase
        .from('goals')
        .update({'current_amount': currentAmount})
        .eq('id', id)
        .select()
        .single();

    return Goal.fromJson(response);
  }

  Future<void> deleteGoal(String id) async {
    await supabase.from('goals').delete().eq('id', id);
  }
}
