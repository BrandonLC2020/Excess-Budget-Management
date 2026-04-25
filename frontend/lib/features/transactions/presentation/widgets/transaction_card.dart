import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

    return Dismissible(
      key: ValueKey(title + date.toString() + amount.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isExpense
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.1),
            child: Icon(
              isExpense ? Icons.arrow_downward : Icons.arrow_upward,
              color: isExpense ? Colors.red : Colors.green,
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          trailing: Text(
            formatCurrency.format(amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isExpense ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
