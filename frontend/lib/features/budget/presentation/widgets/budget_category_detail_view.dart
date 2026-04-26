import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/budget_bloc.dart';
import '../../bloc/budget_category_detail_bloc.dart';
import '../../bloc/budget_category_detail_event.dart';
import '../../bloc/budget_category_detail_state.dart';
import '../../models/budget_category.dart';
import '../../models/expense.dart';
import '../../../income/models/income.dart';
import 'budget_category_form_sheet.dart';
import '../../repositories/budget_repository.dart';

class BudgetCategoryDetailView extends StatelessWidget {
  final BudgetCategory category;

  const BudgetCategoryDetailView({super.key, required this.category});

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.grey;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BudgetCategoryDetailBloc(
        repository: context.read<BudgetRepository>(),
      )..add(LoadBudgetCategoryDetail(category)),
      child: BlocBuilder<BudgetCategoryDetailBloc, BudgetCategoryDetailState>(
        builder: (context, state) {
          final currentCategory = state.category ?? category;
          final categoryColor = _parseColor(currentCategory.colorHex);
          final categoryIcon = currentCategory.iconCode != null
              ? IconData(currentCategory.iconCode!, fontFamily: 'MaterialIcons')
              : Icons.category;

          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditForm(context, currentCategory),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error),
                  onPressed: () => _showDeleteDialog(context, currentCategory),
                ),
              ],
            ),
            body: state.isLoading && state.category == null
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(context, state, currentCategory, categoryColor,
                    categoryIcon),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    BudgetCategoryDetailState state,
    BudgetCategory category,
    Color color,
    IconData icon,
  ) {
    final formatCurrency = NumberFormat.simpleCurrency();
    final percent = category.limitAmount > 0
        ? (category.spentAmount / category.limitAmount).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Center(
            child: Column(
              children: [
                Hero(
                  tag: 'category_icon_${category.id}',
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 48),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                ),
                Text(
                  category.type == BudgetCategoryType.income
                      ? 'Income Category'
                      : 'Expense Category',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Progress Section
          Text(
            category.type == BudgetCategoryType.income
                ? 'Saving Progress'
                : 'Budget Spending',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildProgressCard(context, category, percent, color, formatCurrency),
          const SizedBox(height: 40),

          // Transactions Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (state.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTransactionsList(context, state, formatCurrency),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    BudgetCategory category,
    double percent,
    Color color,
    NumberFormat format,
  ) {
    final remaining = category.limitAmount - category.spentAmount;
    final isOver = category.type == BudgetCategoryType.expense && remaining < 0;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.type == BudgetCategoryType.income
                          ? 'Saved'
                          : 'Spent',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    Text(
                      format.format(category.spentAmount),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Goal / Limit',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    Text(
                      format.format(category.limitAmount),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Stack(
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 12,
                  width: (MediaQuery.of(context).size.width - 96) * percent,
                  decoration: BoxDecoration(
                    color: category.type == BudgetCategoryType.income
                        ? (percent >= 1.0 ? Colors.green : color)
                        : (percent >= 1.0
                            ? Theme.of(context).colorScheme.error
                            : color),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(percent * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  category.type == BudgetCategoryType.income
                      ? (remaining <= 0
                          ? 'Goal Reached!'
                          : '${format.format(remaining)} remaining')
                      : (remaining < 0
                          ? '${format.format(remaining.abs())} over budget'
                          : '${format.format(remaining)} remaining'),
                  style: TextStyle(
                    color: isOver
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.outline,
                    fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(
    BuildContext context,
    BudgetCategoryDetailState state,
    NumberFormat format,
  ) {
    final transactions = state.category?.type == BudgetCategoryType.income
        ? state.income
        : state.expenses;

    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found for this category',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isExpense = tx is Expense;
        final amount = isExpense ? tx.amount : (tx as Income).amount;
        final date = isExpense ? tx.date : (tx as Income).dateReceived;
        final desc = isExpense ? tx.description : (tx as Income).description;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isExpense
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.1),
            child: Icon(
              isExpense ? Icons.remove : Icons.add,
              color: isExpense ? Colors.red : Colors.green,
              size: 18,
            ),
          ),
          title: Text(desc?.isNotEmpty == true
              ? desc!
              : (isExpense ? 'Expense' : 'Income')),
          subtitle: Text(DateFormat.yMMMd().format(date)),
          trailing: Text(
            (isExpense ? '-' : '+') + format.format(amount),
            style: TextStyle(
              color: isExpense ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  void _showEditForm(BuildContext context, BudgetCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BudgetCategoryFormSheet(category: category),
      ),
    ).then((_) {
      // After editing, refresh details
      if (context.mounted) {
        context.read<BudgetCategoryDetailBloc>().add(
            RefreshBudgetCategoryDetail(category.id, category.type));
      }
    });
  }

  void _showDeleteDialog(BuildContext context, BudgetCategory category) {
    final budgetBloc = context.read<BudgetBloc>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Are you sure you want to delete "${category.name}"? This will not delete the associated transactions but they will no longer be linked to this category.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              budgetBloc.add(DeleteBudgetCategory(category.id));
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close detail view
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
