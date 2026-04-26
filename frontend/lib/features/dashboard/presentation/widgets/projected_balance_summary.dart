import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../accounts/bloc/account_bloc.dart';
import '../../../budget/bloc/bulk_expenses_bloc.dart';
import '../../../income/bloc/bulk_income_bloc.dart';

class ProjectedBalanceSummary extends StatelessWidget {
  const ProjectedBalanceSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, accountState) {
        if (accountState is! AccountLoaded) return const SizedBox.shrink();

        return BlocBuilder<BulkExpensesBloc, BulkExpensesState>(
          builder: (context, expenseState) {
            return BlocBuilder<BulkIncomeBloc, BulkIncomeState>(
              builder: (context, incomeState) {
                final deltas = _calculateDeltas(expenseState, incomeState);
                if (deltas.isEmpty) return const SizedBox.shrink();

                final affectedAccounts = accountState.accounts
                    .where((acc) => deltas.containsKey(acc.id))
                    .toList();

                if (affectedAccounts.isEmpty) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projected Balances',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: affectedAccounts.map((account) {
                            final delta = deltas[account.id]!;
                            final projected = account.balance + delta;
                            final currencyFormat = NumberFormat.currency(
                              symbol: '\$',
                            );

                            return Container(
                              margin: const EdgeInsets.only(right: 16),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        currencyFormat.format(account.balance),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const Icon(Icons.arrow_forward, size: 12),
                                      Text(
                                        currencyFormat.format(projected),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: delta > 0
                                                  ? Colors.green
                                                  : (delta < 0
                                                        ? Colors.red
                                                        : null),
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '(${delta >= 0 ? '+' : ''}${currencyFormat.format(delta)})',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: delta > 0
                                              ? Colors.green
                                              : (delta < 0 ? Colors.red : null),
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Map<String, double> _calculateDeltas(
    BulkExpensesState expenseState,
    BulkIncomeState incomeState,
  ) {
    final deltas = <String, double>{};
    for (var row in expenseState.rows) {
      if (row.accountId != null && row.amount != null) {
        deltas[row.accountId!] = (deltas[row.accountId!] ?? 0) - row.amount!;
      }
    }
    for (var row in incomeState.rows) {
      if (row.accountId != null && row.amount != null) {
        deltas[row.accountId!] = (deltas[row.accountId!] ?? 0) + row.amount!;
      }
    }
    return deltas;
  }
}
