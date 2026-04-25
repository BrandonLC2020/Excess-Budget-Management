import 'package:flutter_bloc/flutter_bloc.dart';
import '../../budget/repositories/budget_repository.dart';
import 'transaction_expenses_event.dart';
import 'transaction_expenses_state.dart';

class TransactionExpensesBloc
    extends Bloc<TransactionExpensesEvent, TransactionExpensesState> {
  final BudgetRepository budgetRepository;

  TransactionExpensesBloc({required this.budgetRepository})
    : super(TransactionExpensesInitial()) {
    on<FetchTransactionExpenses>(_onFetchTransactionExpenses);
    on<DeleteTransactionExpense>(_onDeleteTransactionExpense);
  }

  Future<void> _onFetchTransactionExpenses(
    FetchTransactionExpenses event,
    Emitter<TransactionExpensesState> emit,
  ) async {
    emit(TransactionExpensesLoading());
    try {
      final expenses = await budgetRepository.getExpenses();
      emit(TransactionExpensesLoaded(expenses));
    } catch (e) {
      emit(TransactionExpensesError(e.toString()));
    }
  }

  Future<void> _onDeleteTransactionExpense(
    DeleteTransactionExpense event,
    Emitter<TransactionExpensesState> emit,
  ) async {
    try {
      await budgetRepository.deleteExpense(event.id);
      add(FetchTransactionExpenses()); // Refresh list
    } catch (e) {
      // Could emit a specific error state or just log for now
      emit(TransactionExpensesError('Failed to delete: ${e.toString()}'));
    }
  }
}
