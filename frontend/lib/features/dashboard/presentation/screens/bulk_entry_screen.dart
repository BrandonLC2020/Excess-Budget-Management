import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../budget/bloc/budget_bloc.dart';
import '../../../budget/bloc/bulk_expenses_bloc.dart';
import '../../../budget/repositories/budget_repository.dart';
import '../../../income/bloc/bulk_income_bloc.dart';
import '../../../income/repositories/income_repository.dart';
import '../../../budget/presentation/widgets/bulk_expense_tab.dart';
import '../../../income/presentation/widgets/bulk_income_tab.dart';
import '../widgets/projected_balance_summary.dart';

class BulkEntryScreen extends StatelessWidget {
  const BulkEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => BulkExpensesBloc(
            repository: BudgetRepository(supabase: Supabase.instance.client),
          ),
        ),
        BlocProvider(
          create: (context) => BulkIncomeBloc(
            repository: IncomeRepository(supabase: Supabase.instance.client),
          ),
        ),
        // Ensure BudgetBloc is loaded so the category dropdown works
        BlocProvider.value(
          value: context.read<BudgetBloc>()..add(LoadBudgets()),
        ),
      ],
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Bulk Entry'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Expenses'),
                Tab(text: 'Income'),
              ],
            ),
          ),
          body: const TabBarView(children: [BulkExpenseTab(), BulkIncomeTab()]),
          bottomNavigationBar: const ProjectedBalanceSummary(),
        ),
      ),
    );
  }
}
