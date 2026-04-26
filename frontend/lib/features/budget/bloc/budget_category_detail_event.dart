import 'package:equatable/equatable.dart';
import '../models/budget_category.dart';

abstract class BudgetCategoryDetailEvent extends Equatable {
  const BudgetCategoryDetailEvent();
  @override
  List<Object?> get props => [];
}

class LoadBudgetCategoryDetail extends BudgetCategoryDetailEvent {
  final BudgetCategory category;
  const LoadBudgetCategoryDetail(this.category);
  @override
  List<Object?> get props => [category];
}

class RefreshBudgetCategoryDetail extends BudgetCategoryDetailEvent {
  final String categoryId;
  final BudgetCategoryType type;
  const RefreshBudgetCategoryDetail(this.categoryId, this.type);
  @override
  List<Object?> get props => [categoryId, type];
}
