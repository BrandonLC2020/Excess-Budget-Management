import 'package:equatable/equatable.dart';
import 'sub_goal.dart';

class Goal extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String type;
  final String category;
  final DateTime createdAt;
  final List<SubGoal> subGoals;
  final List<String> accountIds;

  const Goal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.type,
    required this.category,
    required this.createdAt,
    this.subGoals = const [],
    this.accountIds = const [],
  });

  bool get isCompleted => targetAmount > 0 && currentAmount >= targetAmount;

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        targetAmount,
        currentAmount,
        targetDate,
        type,
        category,
        createdAt,
        subGoals,
        accountIds,
      ];

  factory Goal.fromJson(Map<String, dynamic> json) {
    // goal_accounts is Supabase-only join syntax; Django API uses a flat list
    // under the same key populated via GoalOut (not present yet) or omitted.
    List<String> parsedAccountIds = [];
    if (json['goal_accounts'] != null) {
      parsedAccountIds =
          (json['goal_accounts'] as List)
              .map((e) => e['account_id'] as String)
              .toList();
    }

    return Goal(
      id: json['id'] as String,
      // user_id is not included in the Django GoalOut schema (inferred from auth).
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      targetDate:
          json['target_date'] != null
              ? DateTime.parse(json['target_date'] as String)
              : null,
      type: json['type'] as String,
      category: json['category'] as String? ?? 'savings',
      createdAt: DateTime.parse(json['created_at'] as String),
      // sub_goals nested join is Supabase-only; Django API does not embed subgoals
      // in GoalOut — call GET /goals/{id}/subgoals explicitly if needed.
      subGoals:
          (json['sub_goals'] as List<dynamic>?)
              ?.map((e) => SubGoal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      accountIds: parsedAccountIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': targetDate?.toIso8601String(),
      'type': type,
      'category': category,
      'sub_goals': subGoals.map((e) => e.toJson()).toList(),
      // accountIds are handled separately in junction table
    };
  }
}
