import 'package:equatable/equatable.dart';

class Account extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double balance;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    required this.createdAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      balance: (json['balance'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'balance': balance};
  }

  @override
  List<Object?> get props => [id, userId, name, balance, createdAt];
}
