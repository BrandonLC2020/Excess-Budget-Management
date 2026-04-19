class GoalAllocation {
  final String id;
  final String userId;
  final String goalId;
  final String? goalName;
  final double amount;
  final DateTime createdAt;

  GoalAllocation({
    required this.id,
    required this.userId,
    required this.goalId,
    this.goalName,
    required this.amount,
    required this.createdAt,
  });

  factory GoalAllocation.fromJson(Map<String, dynamic> json) {
    return GoalAllocation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      goalId: json['goal_id'] as String,
      goalName: json['goals'] != null ? json['goals']['name'] as String? : null,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {'goal_id': goalId, 'amount': amount};
  }
}
