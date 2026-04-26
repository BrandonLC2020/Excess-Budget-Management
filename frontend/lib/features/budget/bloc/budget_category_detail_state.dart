import 'package:equatable/equatable.dart';
import '../../income/models/income.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';

class BudgetCategoryDetailState extends Equatable {
  final BudgetCategory? category;
  final List<Expense> expenses;
  final List<Income> income;
  final bool isLoading;
  final String? error;

  const BudgetCategoryDetailState({
    this.category,
    this.expenses = const [],
    this.income = const [],
    this.isLoading = false,
    this.error,
  });

  BudgetCategoryDetailState copyWith({
    BudgetCategory? category,
    List<Expense>? expenses,
    List<Income>? income,
    bool? isLoading,
    String? error,
  }) {
    return BudgetCategoryDetailState(
      category: category ?? this.category,
      expenses: expenses ?? this.expenses,
      income: income ?? this.income,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    category,
    expenses,
    income,
    isLoading,
    error,
  ];
}
