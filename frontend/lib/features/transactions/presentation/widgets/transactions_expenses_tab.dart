import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/transaction_expenses_bloc.dart';
import '../../bloc/transaction_expenses_event.dart';
import '../../bloc/transaction_expenses_state.dart';
import 'transaction_card.dart';

class TransactionsExpensesTab extends StatelessWidget {
  const TransactionsExpensesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionExpensesBloc, TransactionExpensesState>(
      builder: (context, state) {
        if (state is TransactionExpensesInitial) {
          context.read<TransactionExpensesBloc>().add(
            FetchTransactionExpenses(),
          );
          return const Center(child: CircularProgressIndicator());
        }
        if (state is TransactionExpensesLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is TransactionExpensesError) {
          return Center(child: Text('Error: ${state.message}'));
        }
        if (state is TransactionExpensesLoaded) {
          final expenses = state.expenses;
          if (expenses.isEmpty) {
            return const Center(child: Text('No expenses found.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<TransactionExpensesBloc>().add(
                FetchTransactionExpenses(),
              );
            },
            child: ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return TransactionCard(
                  title: expense.description ?? 'Expense',
                  amount: expense.amount,
                  date: expense.date,
                  isExpense: true,
                  accountId: expense.accountId,
                  onDelete: () {
                    context.read<TransactionExpensesBloc>().add(
                      DeleteTransactionExpense(expense.id),
                    );
                  },
                );
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
