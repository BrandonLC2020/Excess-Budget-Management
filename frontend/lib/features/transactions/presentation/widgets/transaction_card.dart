import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/llc_theme.dart';
import '../../../../core/theme/refractive_glass.dart';

class TransactionCard extends StatelessWidget {
  final String title;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final VoidCallback onDelete;
  final String? accountId;

  const TransactionCard({
    super.key,
    required this.title,
    required this.amount,
    required this.date,
    required this.isExpense,
    required this.onDelete,
    this.accountId,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.simpleCurrency();
    final formatDate = DateFormat.yMMMd();
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = isExpense ? colorScheme.error : LLCColors.affirmMint;
    final sign = isExpense ? '-' : '+';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Dismissible(
        key: ValueKey(title + date.toString() + amount.toString()),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          decoration: BoxDecoration(
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: Icon(Icons.delete, color: LLCColors.chromeWhite),
        ),
        child: RefractiveGlass(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(
                isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                color: statusColor,
              ),
            ),
            title: Text(
              title.isNotEmpty ? title : (isExpense ? 'Expense' : 'Income'),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDate.format(date)),
                if (accountId != null)
                  Text(
                    'Account Linked',
                    style: TextStyle(fontSize: 12, color: colorScheme.primary),
                  ),
              ],
            ),
            trailing: Text(
              '$sign${formatCurrency.format(amount)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
