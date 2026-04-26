import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../features/budget/models/expense.dart';
import '../../../../features/income/models/income.dart';
import '../../bloc/account_bloc.dart';
import '../../bloc/account_detail_bloc.dart';
import '../../bloc/account_detail_event.dart';
import '../../bloc/account_detail_state.dart';
import '../../models/account.dart';
import '../../repositories/account_repository.dart';

class AccountForm extends StatefulWidget {
  final Account? account;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  const AccountForm({super.key, this.account, this.onSaved, this.onCancel});

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  late TextEditingController _nameController;
  late TextEditingController _balanceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name);
    _balanceController = TextEditingController(
      text: widget.account?.balance.toString() ?? '0.0',
    );
  }

  @override
  void didUpdateWidget(AccountForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.account != oldWidget.account) {
      _nameController.text = widget.account?.name ?? '';
      _balanceController.text = widget.account?.balance.toString() ?? '0.0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;

    if (name.isNotEmpty) {
      if (widget.account == null) {
        context.read<AccountBloc>().add(AddAccount(name, balance));
      } else {
        context.read<AccountBloc>().add(
          UpdateAccount(widget.account!.id, name, balance),
        );
      }
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Account Name',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _balanceController,
          decoration: const InputDecoration(
            labelText: 'Balance',
            border: OutlineInputBorder(),
            prefixText: '\$',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            if (widget.onCancel != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AccountDetailView extends StatelessWidget {
  final Account account;
  final VoidCallback? onDelete;

  const AccountDetailView({super.key, required this.account, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => AccountDetailBloc(
            repository: context.read<AccountRepository>(),
          )..add(LoadAccountDetail(account)),
      child: BlocBuilder<AccountDetailBloc, AccountDetailState>(
        builder: (context, state) {
          if (state.isLoading && state.account == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.isEditing) {
            return _buildEditMode(context, state);
          }

          return _buildViewMode(context, state);
        },
      ),
    );
  }

  Widget _buildViewMode(BuildContext context, AccountDetailState state) {
    final account = state.account ?? this.account;
    final formatCurrency = NumberFormat.simpleCurrency();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, account),
          const SizedBox(height: 32),
          _buildBalanceSection(context, account, formatCurrency),
          const SizedBox(height: 32),
          _buildTransactionsSection(context, state, formatCurrency),
          const SizedBox(height: 32),
          _buildHistorySection(context, account),
        ],
      ),
    );
  }

  Widget _buildEditMode(BuildContext context, AccountDetailState state) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Account',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          AccountForm(
            account: state.account ?? account,
            onSaved: () {
              context.read<AccountDetailBloc>().add(const ToggleEditMode(false));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Account updated')));
            },
            onCancel: () {
              context.read<AccountDetailBloc>().add(const ToggleEditMode(false));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Account account) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Personal Account',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                context.read<AccountDetailBloc>().add(const ToggleEditMode(true));
              },
              tooltip: 'Edit Account',
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteDialog(context, account),
              tooltip: 'Delete Account',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceSection(
    BuildContext context,
    Account account,
    NumberFormat format,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.3,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Balance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              format.format(account.balance),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection(
    BuildContext context,
    AccountDetailState state,
    NumberFormat format,
  ) {
    final transactions = [...state.expenses, ...state.income];
    transactions.sort((a, b) {
      final dateA = (a is Expense) ? a.date : (a as Income).dateReceived;
      final dateB = (b is Expense) ? b.date : (b as Income).dateReceived;
      return dateB.compareTo(dateA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Transactions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length > 5 ? 5 : transactions.length,
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
                  backgroundColor:
                      isExpense
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                  child: Icon(
                    isExpense ? Icons.remove : Icons.add,
                    color: isExpense ? Colors.red : Colors.green,
                    size: 18,
                  ),
                ),
                title: Text(desc?.isNotEmpty == true ? desc! : (isExpense ? 'Expense' : 'Income')),
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
          ),
      ],
    );
  }

  Widget _buildHistorySection(BuildContext context, Account account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'History',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildTimelineItem(
          context,
          'Current Balance',
          'Current state of the account',
          DateFormat.yMMMd().format(DateTime.now()),
          isLast: false,
          icon: Icons.account_balance_wallet_outlined,
        ),
        _buildTimelineItem(
          context,
          'Account Created',
          'Account was initialized',
          DateFormat.yMMMd().format(account.createdAt),
          isLast: true,
          icon: Icons.cake_outlined,
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    String title,
    String subtitle,
    String date, {
    required bool isLast,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, Account account) {
    final accountBloc = context.read<AccountBloc>();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: Text('Are you sure you want to delete "${account.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  accountBloc.add(DeleteAccount(account.id));
                  Navigator.pop(context);
                  onDelete?.call();
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
