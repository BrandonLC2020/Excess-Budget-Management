// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'income.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Income _$IncomeFromJson(Map<String, dynamic> json) => Income(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  amount: (json['amount'] as num).toDouble(),
  description: json['description'] as String?,
  dateReceived: DateTime.parse(json['date_received'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  accountId: json['account_id'] as String?,
  categoryId: json['budget_category_id'] as String?,
);

Map<String, dynamic> _$IncomeToJson(Income instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'amount': instance.amount,
  'description': instance.description,
  'date_received': instance.dateReceived.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'account_id': instance.accountId,
  'budget_category_id': instance.categoryId,
};
