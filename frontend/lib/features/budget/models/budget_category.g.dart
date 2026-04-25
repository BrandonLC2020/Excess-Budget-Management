// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BudgetCategory _$BudgetCategoryFromJson(Map<String, dynamic> json) =>
    BudgetCategory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      limitAmount: (json['limit_amount'] as num).toDouble(),
      spentAmount: (json['spent_amount'] as num).toDouble(),
      iconCode: (json['icon_code'] as num?)?.toInt(),
      colorHex: json['color_hex'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      type:
          $enumDecodeNullable(
            _$BudgetCategoryTypeEnumMap,
            json['category_type'],
          ) ??
          BudgetCategoryType.expense,
    );

Map<String, dynamic> _$BudgetCategoryToJson(BudgetCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'name': instance.name,
      'limit_amount': instance.limitAmount,
      'spent_amount': instance.spentAmount,
      'icon_code': instance.iconCode,
      'color_hex': instance.colorHex,
      'created_at': instance.createdAt.toIso8601String(),
      'category_type': _$BudgetCategoryTypeEnumMap[instance.type]!,
    };

const _$BudgetCategoryTypeEnumMap = {
  BudgetCategoryType.expense: 'expense',
  BudgetCategoryType.income: 'income',
};
