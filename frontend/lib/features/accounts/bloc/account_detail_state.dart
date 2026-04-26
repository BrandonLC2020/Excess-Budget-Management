import 'package:equatable/equatable.dart';
import '../../budget/models/expense.dart';
import '../../income/models/income.dart';
import '../models/account.dart';

class AccountDetailState extends Equatable {
  final Account? account;
  final List<Expense> expenses;
  final List<Income> income;
  final bool isLoading;
  final String? error;
  final bool isEditing;

  const AccountDetailState({
    this.account,
    this.expenses = const [],
    this.income = const [],
    this.isLoading = false,
    this.error,
    this.isEditing = false,
  });

  AccountDetailState copyWith({
    Account? account,
    List<Expense>? expenses,
    List<Income>? income,
    bool? isLoading,
    String? error,
    bool? isEditing,
  }) {
    return AccountDetailState(
      account: account ?? this.account,
      expenses: expenses ?? this.expenses,
      income: income ?? this.income,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  @override
  List<Object?> get props => [
    account,
    expenses,
    income,
    isLoading,
    error,
    isEditing,
  ];
}
