import 'package:flutter_bloc/flutter_bloc.dart';
import '../../income/repositories/income_repository.dart';
import 'transaction_income_event.dart';
import 'transaction_income_state.dart';

class TransactionIncomeBloc
    extends Bloc<TransactionIncomeEvent, TransactionIncomeState> {
  final IncomeRepository incomeRepository;

  TransactionIncomeBloc({required this.incomeRepository})
    : super(TransactionIncomeInitial()) {
    on<FetchTransactionIncome>(_onFetchTransactionIncome);
    on<DeleteTransactionIncome>(_onDeleteTransactionIncome);
  }

  Future<void> _onFetchTransactionIncome(
    FetchTransactionIncome event,
    Emitter<TransactionIncomeState> emit,
  ) async {
    emit(TransactionIncomeLoading());
    try {
      final income = await incomeRepository.getIncome();
      emit(TransactionIncomeLoaded(income));
    } catch (e) {
      emit(TransactionIncomeError(e.toString()));
    }
  }

  Future<void> _onDeleteTransactionIncome(
    DeleteTransactionIncome event,
    Emitter<TransactionIncomeState> emit,
  ) async {
    try {
      await incomeRepository.deleteIncome(event.id);
      add(FetchTransactionIncome()); // Refresh list
    } catch (e) {
      emit(TransactionIncomeError('Failed to delete: ${e.toString()}'));
    }
  }
}
