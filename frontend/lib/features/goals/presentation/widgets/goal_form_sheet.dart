import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/goal.dart';
import '../../../accounts/bloc/account_bloc.dart';

class GoalFormSheet extends StatefulWidget {
  final Goal? goal;
  final Function(
    String name,
    double targetAmount,
    String type,
    String category,
    DateTime? targetDate,
    List<String> accountIds,
  )
  onSave;

  const GoalFormSheet({super.key, this.goal, required this.onSave});

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _targetAmountController;
  late String _type;
  late String _category;
  DateTime? _targetDate;
  List<String> _accountIds = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal?.name ?? '');
    _targetAmountController = TextEditingController(
      text: widget.goal?.targetAmount.toString() ?? '',
    );
    _type = widget.goal?.type ?? 'short_term';
    _category = widget.goal?.category ?? 'savings';
    _targetDate = widget.goal?.targetDate;
    _accountIds = widget.goal?.accountIds.toList() ?? [];

    // Load accounts if not already loaded
    final accountBloc = context.read<AccountBloc>();
    if (accountBloc.state is! AccountLoaded) {
      accountBloc.add(LoadAccounts());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.goal == null ? 'Add Goal' : 'Edit Goal',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Goal Name'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetAmountController,
                decoration: const InputDecoration(
                  labelText: 'Target Amount',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || double.tryParse(value) == null
                    ? 'Please enter a valid amount'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Goal Horizon'),
                items: const [
                  DropdownMenuItem(
                    value: 'short_term',
                    child: Text('Short Term'),
                  ),
                  DropdownMenuItem(
                    value: 'long_term',
                    child: Text('Long Term'),
                  ),
                ],
                onChanged: (val) => setState(() => _type = val!),
              ),
              const SizedBox(height: 16),
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'savings',
                    label: Text('Savings'),
                    icon: Icon(Icons.savings_outlined),
                  ),
                  ButtonSegment(
                    value: 'purchase',
                    label: Text('Purchase'),
                    icon: Icon(Icons.shopping_bag_outlined),
                  ),
                ],
                selected: {_category},
                onSelectionChanged: (val) =>
                    setState(() => _category = val.first),
              ),
              const SizedBox(height: 16),
              BlocBuilder<AccountBloc, AccountState>(
                builder: (context, state) {
                  if (state is AccountLoaded) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto-sync with Accounts (Optional)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children:
                              state.accounts.map((account) {
                                final isSelected = _accountIds.contains(
                                  account.id,
                                );
                                return FilterChip(
                                  label: Text(account.name),
                                  selected: isSelected,
                                  onSelected: (bool selected) {
                                    setState(() {
                                      if (selected) {
                                        _accountIds.add(account.id);
                                      } else {
                                        _accountIds.remove(account.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                        ),
                        if (_accountIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: Colors.amber,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'When synced, manual progress updates will be disabled. Progress is the sum of linked account balances.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Target Date (Optional)'),
                subtitle: Text(
                  _targetDate == null
                      ? 'Not set'
                      : _targetDate!.toLocal().toString().split(' ')[0],
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate:
                        _targetDate ??
                        DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) setState(() => _targetDate = date);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onSave(
                      _nameController.text,
                      double.parse(_targetAmountController.text),
                      _type,
                      _category,
                      _targetDate,
                      _accountIds,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save Goal'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
