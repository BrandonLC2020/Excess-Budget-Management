import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'budget_category.g.dart';

enum BudgetCategoryType { expense, income }

@JsonSerializable(fieldRename: FieldRename.snake)
class BudgetCategory extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double limitAmount;
  final double spentAmount;
  final int? iconCode;
  final String? colorHex;
  final DateTime createdAt;
  @JsonKey(name: 'category_type', defaultValue: BudgetCategoryType.expense)
  final BudgetCategoryType type;

  const BudgetCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.limitAmount,
    required this.spentAmount,
    this.iconCode,
    this.colorHex,
    required this.createdAt,
    this.type = BudgetCategoryType.expense,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) =>
      _$BudgetCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$BudgetCategoryToJson(this);

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    limitAmount,
    spentAmount,
    iconCode,
    colorHex,
    createdAt,
    type,
  ];
}
