import 'sub_goal.dart';

class Goal {
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

  Goal({
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
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      targetDate: json['target_date'] != null ? DateTime.parse(json['target_date'] as String) : null,
      type: json['type'] as String,
      category: json['category'] as String? ?? 'savings',
      createdAt: DateTime.parse(json['created_at'] as String),
      subGoals: (json['sub_goals'] as List<dynamic>?)
              ?.map((e) => SubGoal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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
    };
  }
}
