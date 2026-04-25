import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/transaction_income_bloc.dart';
import '../../bloc/transaction_income_event.dart';
import '../../bloc/transaction_income_state.dart';
import 'transaction_card.dart';

class TransactionsIncomeTab extends StatelessWidget {
  const TransactionsIncomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionIncomeBloc, TransactionIncomeState>(
      builder: (context, state) {
        if (state is TransactionIncomeInitial) {
          context.read<TransactionIncomeBloc>().add(FetchTransactionIncome());
          return const Center(child: CircularProgressIndicator());
        }
        if (state is TransactionIncomeLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is TransactionIncomeError) {
          return Center(child: Text('Error: ${state.message}'));
        }
        if (state is TransactionIncomeLoaded) {
          final income = state.income;
          if (income.isEmpty) {
            return const Center(child: Text('No income found.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<TransactionIncomeBloc>().add(
                FetchTransactionIncome(),
              );
            },
            child: ListView.builder(
              itemCount: income.length,
              itemBuilder: (context, index) {
                final inc = income[index];
                return TransactionCard(
                  title: inc.description ?? 'Income',
                  amount: inc.amount,
                  date: inc.dateReceived,
                  isExpense: false,
                  accountId: inc.accountId,
                  onDelete: () {
                    context.read<TransactionIncomeBloc>().add(
                      DeleteTransactionIncome(inc.id),
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
