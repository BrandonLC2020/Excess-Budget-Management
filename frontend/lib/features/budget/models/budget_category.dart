class BudgetCategory {
  final String id;
  final String userId;
  final String name;
  final double limitAmount;
  final double spentAmount;
  final DateTime createdAt;

  BudgetCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.limitAmount,
    required this.spentAmount,
    required this.createdAt,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      limitAmount: (json['limit_amount'] as num).toDouble(),
      spentAmount: (json['spent_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'limit_amount': limitAmount,
      'spent_amount': spentAmount,
    };
  }
}
