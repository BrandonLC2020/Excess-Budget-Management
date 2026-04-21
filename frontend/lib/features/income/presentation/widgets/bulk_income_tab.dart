import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/bulk_income_bloc.dart';
import '../../accounts/bloc/account_bloc.dart';
import '../../accounts/models/account.dart';

class BulkIncomeTab extends StatelessWidget {
  const BulkIncomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BulkIncomeBloc, BulkIncomeState>(
      listener: (context, state) {
        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Income saved successfully')));
          Navigator.of(context).pop();
        }
        if (state.submissionError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.submissionError!), backgroundColor: Colors.red));
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
                              Text('Income ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => context.read<BulkIncomeBloc>().add(RemoveIncomeRow(row.id)),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: row.amount?.toString(),
                                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (val) => context.read<BulkIncomeBloc>().add(UpdateIncomeRow(rowId: row.id, amount: double.tryParse(val))),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  initialValue: row.description,
                                  decoration: const InputDecoration(labelText: 'Source/Description'),
                                  onChanged: (val) => context.read<BulkIncomeBloc>().add(UpdateIncomeRow(rowId: row.id, description: val)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          BlocBuilder<AccountBloc, AccountState>(
                            builder: (context, accountState) {
                              List<Account> accounts = [];
                              if (accountState is AccountLoaded) accounts = accountState.accounts;

                              return DropdownButtonFormField<String>(
                                value: row.accountId,
                                decoration: const InputDecoration(
                                  labelText: 'Account (Optional)',
                                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                                  helperText: 'Affects account balance if selected',
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('No Account'),
                                  ),
                                  ...accounts.map((a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text(a.name),
                                      )),
                                ],
                                onChanged: (val) => context.read<BulkIncomeBloc>().add(
                                      UpdateIncomeRow(
                                        rowId: row.id,
                                        accountId: val,
                                      ),
                                    ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(context: context, initialDate: row.dateReceived, firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (date != null && context.mounted) {
                                context.read<BulkIncomeBloc>().add(UpdateIncomeRow(rowId: row.id, dateReceived: date));
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Date Received'),
                              child: Text(DateFormat.yMMMd().format(row.dateReceived)),
                            ),
                          ),
                          if (row.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(row.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            )
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
                    onPressed: () => context.read<BulkIncomeBloc>().add(AddIncomeRow()),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Row'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: state.isSubmitting ? null : () => context.read<BulkIncomeBloc>().add(SubmitBulkIncome()),
                    icon: state.isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: const Text('Save All Income'),
                  ),
                ],
              ),
            )
          ],
        );
      },
    );
  }
}
