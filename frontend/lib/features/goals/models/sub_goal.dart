class SubGoal {
  final String id;
  final String goalId;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime createdAt;

  SubGoal({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.createdAt,
  });

  factory SubGoal.fromJson(Map<String, dynamic> json) {
    return SubGoal(
      id: json['id'] as String,
      goalId: json['goal_id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goal_id': goalId,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
    };
  }
}
