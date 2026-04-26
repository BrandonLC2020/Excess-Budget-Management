import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/budget_category.dart';
import '../repositories/budget_repository.dart';
import 'budget_category_detail_event.dart';
import 'budget_category_detail_state.dart';

class BudgetCategoryDetailBloc
    extends Bloc<BudgetCategoryDetailEvent, BudgetCategoryDetailState> {
  final BudgetRepository repository;

  BudgetCategoryDetailBloc({required this.repository})
    : super(const BudgetCategoryDetailState()) {
    on<LoadBudgetCategoryDetail>(_onLoadBudgetCategoryDetail);
    on<RefreshBudgetCategoryDetail>(_onRefreshBudgetCategoryDetail);
  }

  Future<void> _onLoadBudgetCategoryDetail(
    LoadBudgetCategoryDetail event,
    Emitter<BudgetCategoryDetailState> emit,
  ) async {
    emit(state.copyWith(category: event.category, isLoading: true));
    try {
      if (event.category.type == BudgetCategoryType.expense) {
        final expenses = await repository.getCategoryExpenses(event.category.id);
        emit(state.copyWith(expenses: expenses, income: [], isLoading: false));
      } else {
        final income = await repository.getCategoryIncome(event.category.id);
        emit(state.copyWith(income: income, expenses: [], isLoading: false));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onRefreshBudgetCategoryDetail(
    RefreshBudgetCategoryDetail event,
    Emitter<BudgetCategoryDetailState> emit,
  ) async {
    try {
      if (event.type == BudgetCategoryType.expense) {
        final expenses = await repository.getCategoryExpenses(event.categoryId);
        emit(state.copyWith(expenses: expenses, income: []));
      } else {
        final income = await repository.getCategoryIncome(event.categoryId);
        emit(state.copyWith(income: income, expenses: []));
      }
    } catch (e) {
      // Silent error for refresh
    }
  }
}
