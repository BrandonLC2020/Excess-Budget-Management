import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/account_repository.dart';
import 'account_detail_event.dart';
import 'account_detail_state.dart';

class AccountDetailBloc extends Bloc<AccountDetailEvent, AccountDetailState> {
  final AccountRepository repository;

  AccountDetailBloc({required this.repository}) : super(const AccountDetailState()) {
    on<LoadAccountDetail>(_onLoadAccountDetail);
    on<ToggleEditMode>(_onToggleEditMode);
    on<RefreshAccountDetail>(_onRefreshAccountDetail);
  }

  Future<void> _onLoadAccountDetail(
    LoadAccountDetail event,
    Emitter<AccountDetailState> emit,
  ) async {
    emit(state.copyWith(account: event.account, isLoading: true, isEditing: false));
    try {
      final expenses = await repository.getAccountExpenses(event.account.id);
      final income = await repository.getAccountIncome(event.account.id);
      emit(state.copyWith(
        expenses: expenses,
        income: income,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  void _onToggleEditMode(
    ToggleEditMode event,
    Emitter<AccountDetailState> emit,
  ) {
    emit(state.copyWith(isEditing: event.isEditing));
  }

  Future<void> _onRefreshAccountDetail(
    RefreshAccountDetail event,
    Emitter<AccountDetailState> emit,
  ) async {
    try {
      final expenses = await repository.getAccountExpenses(event.accountId);
      final income = await repository.getAccountIncome(event.accountId);
      emit(state.copyWith(
        expenses: expenses,
        income: income,
      ));
    } catch (e) {
      // Just log or ignore for silent refresh
    }
  }
}
