import 'package:flutter/material.dart';
import '../../models/goal.dart';

class GoalFormSheet extends StatefulWidget {
  final Goal? goal;
  final Function(
    String name,
    double targetAmount,
    String type,
    String category,
    DateTime? targetDate,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.goal == null ? 'Add Goal' : 'Edit Goal',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Goal Name'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter a name' : null,
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
                DropdownMenuItem(value: 'long_term', child: Text('Long Term')),
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
    );
  }
}
