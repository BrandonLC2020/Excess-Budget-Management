import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/budget_bloc.dart';
import '../../bloc/bulk_expenses_bloc.dart';
import '../../models/budget_category.dart';
import '../../../accounts/bloc/account_bloc.dart';
import '../../../accounts/models/account.dart';
import '../../../../core/utils/optional.dart';

class BulkExpenseTab extends StatelessWidget {
  const BulkExpenseTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BulkExpensesBloc, BulkExpensesState>(
      listener: (context, state) {
        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expenses saved successfully')),
          );
          // Normally would pop, but we leave it to the shell to decide, or clear state.
          Navigator.of(context).pop();
        }
        if (state.submissionError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.submissionError!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.rows.length,
                itemBuilder: (context, index) {
                  final row = state.rows[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Expense ${index + 1}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => context
                                    .read<BulkExpensesBloc>()
                                    .add(RemoveExpenseRow(row.id)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: row.amount?.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    prefixText: '\$',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (val) =>
                                      context.read<BulkExpensesBloc>().add(
                                        UpdateExpenseRow(
                                          rowId: row.id,
                                          amount: Wrapped(double.tryParse(val)),
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: BlocBuilder<BudgetBloc, BudgetState>(
                                  builder: (context, budgetState) {
                                    List<BudgetCategory> categories = [];
                                    if (budgetState is BudgetLoaded) {
                                      categories = budgetState.categories;
                                    }

                                    return DropdownButtonFormField<String>(
                                      initialValue: row.budgetCategoryId,
                                      decoration: const InputDecoration(
                                        labelText: 'Category',
                                      ),
                                      items: categories
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c.id,
                                              child: Text(c.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) =>
                                          context.read<BulkExpensesBloc>().add(
                                            UpdateExpenseRow(
                                              rowId: row.id,
                                              budgetCategoryId: Wrapped(val),
                                            ),
                                          ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          BlocBuilder<AccountBloc, AccountState>(
                            builder: (context, accountState) {
                              List<Account> accounts = [];
                              if (accountState is AccountLoaded) {
                                accounts = accountState.accounts;
                              }

                              return DropdownButtonFormField<String>(
                                initialValue: row.accountId,
                                decoration: const InputDecoration(
                                  labelText: 'Account (Optional)',
                                  prefixIcon: Icon(
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                  helperText:
                                      'Affects account balance if selected',
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('No Account'),
                                  ),
                                  ...accounts.map(
                                    (a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(a.name),
                                    ),
                                  ),
                                ],
                                onChanged: (val) =>
                                    context.read<BulkExpensesBloc>().add(
                                      UpdateExpenseRow(
                                        rowId: row.id,
                                        accountId: Wrapped(val),
                                      ),
                                    ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: row.description,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                  ),
                                  onChanged: (val) =>
                                      context.read<BulkExpensesBloc>().add(
                                        UpdateExpenseRow(
                                          rowId: row.id,
                                          description: Wrapped(val),
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: row.date,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (date != null && context.mounted) {
                                      context.read<BulkExpensesBloc>().add(
                                        UpdateExpenseRow(
                                          rowId: row.id,
                                          date: date,
                                        ),
                                      );
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Date',
                                    ),
                                    child: Text(
                                      DateFormat.yMMMd().format(row.date),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (row.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                row.error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.read<BulkExpensesBloc>().add(AddExpenseRow()),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Row'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: state.isSubmitting
                        ? null
                        : () => context.read<BulkExpensesBloc>().add(
                            SubmitBulkExpenses(),
                          ),
                    icon: state.isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save All Expenses'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
