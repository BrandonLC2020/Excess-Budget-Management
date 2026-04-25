import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../budget/repositories/budget_repository.dart';
import '../../../income/repositories/income_repository.dart';
import '../../bloc/transaction_expenses_bloc.dart';
import '../../bloc/transaction_income_bloc.dart';
import '../widgets/transactions_expenses_tab.dart';
import '../widgets/transactions_income_tab.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => TransactionExpensesBloc(
            budgetRepository: BudgetRepository(supabase: supabase),
          ),
        ),
        BlocProvider(
          create: (context) => TransactionIncomeBloc(
            incomeRepository: IncomeRepository(supabase: supabase),
          ),
        ),
      ],
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Transactions Ledger'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Expenses'),
                Tab(text: 'Income'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [TransactionsExpensesTab(), TransactionsIncomeTab()],
          ),
        ),
      ),
    );
  }
}
