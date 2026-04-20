import '../../accounts/models/account.dart';
import '../../budget/models/budget_category.dart';
import '../../goals/models/allocation.dart';
import '../../goals/models/goal.dart';
import '../models/allocation.dart';

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardDataLoaded extends DashboardState {
  final List<Account> accounts;
  final List<BudgetCategory> budgetCategories;
  final List<Goal> goals;
  final List<GoalAllocation> recentAllocations;

  DashboardDataLoaded({
    required this.accounts,
    required this.budgetCategories,
    required this.goals,
    required this.recentAllocations,
  });
}

class DashboardSuggestionsLoaded extends DashboardState {
  final SuggestionResult result;
  final List<Goal> goals;

  DashboardSuggestionsLoaded(this.result, this.goals);
}

class DashboardError extends DashboardState {
  final String message;

  DashboardError(this.message);
}
