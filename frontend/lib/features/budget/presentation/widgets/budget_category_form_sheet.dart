import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/budget_bloc.dart';
import '../../models/budget_category.dart';
import '../../../../core/utils/validation_utils.dart';

class BudgetCategoryFormSheet extends StatefulWidget {
  final BudgetCategory?
  category; // If null, we are adding. If provided, we are editing.

  const BudgetCategoryFormSheet({super.key, this.category});

  @override
  State<BudgetCategoryFormSheet> createState() =>
      _BudgetCategoryFormSheetState();
}

class _BudgetCategoryFormSheetState extends State<BudgetCategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _limitController;
  late IconData _selectedIcon;
  late Color _selectedColor;
  late BudgetCategoryType _selectedType;

  final List<({String name, IconData icon, Color color})> _presets = [
    (name: 'Groceries', icon: Icons.restaurant, color: Colors.green),
    (name: 'Rent', icon: Icons.home, color: Colors.blue),
    (name: 'Transport', icon: Icons.directions_car, color: Colors.orange),
    (name: 'Dining', icon: Icons.local_dining, color: Colors.red),
    (name: 'Utilities', icon: Icons.bolt, color: Colors.yellow),
    (name: 'Entertainment', icon: Icons.movie, color: Colors.purple),
    (name: 'Healthcare', icon: Icons.medical_services, color: Colors.pink),
    (name: 'Shopping', icon: Icons.shopping_bag, color: Colors.cyan),
  ];

  final List<IconData> _iconOptions = [
    Icons.shopping_bag,
    Icons.restaurant,
    Icons.directions_car,
    Icons.home,
    Icons.bolt,
    Icons.movie,
    Icons.medical_services,
    Icons.flight,
    Icons.school,
    Icons.redeem,
    Icons.category,
    Icons.account_balance,
    Icons.fitness_center,
    Icons.brush,
    Icons.pets,
  ];

  final List<Color> _colorOptions = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _limitController = TextEditingController(
      text: widget.category?.limitAmount.toString() ?? '',
    );
    _selectedIcon = widget.category?.iconCode != null
        ? IconData(widget.category!.iconCode!, fontFamily: 'MaterialIcons')
        : Icons.category;
    _selectedColor = widget.category?.colorHex != null
        ? _parseColor(widget.category!.colorHex!)
        : Colors.grey;
    _selectedType = widget.category?.type ?? BudgetCategoryType.expense;
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  String _toHex(Color color) {
    return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final limit = double.tryParse(_limitController.text.trim()) ?? 0.0;

      if (widget.category == null) {
        context.read<BudgetBloc>().add(
          AddBudgetCategory(
            name,
            limit,
            iconCode: _selectedIcon.codePoint,
            colorHex: _toHex(_selectedColor),
            type: _selectedType,
          ),
        );
      } else {
        context.read<BudgetBloc>().add(
          UpdateBudgetCategory(
            widget.category!.id,
            name,
            limit,
            iconCode: _selectedIcon.codePoint,
            colorHex: _toHex(_selectedColor),
            type: _selectedType,
          ),
        );
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen height for dynamic bottom sheet padding to handle keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 24.0,
        bottom: bottomInset > 0 ? bottomInset + 16.0 : 24.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle Handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                widget.category == null
                    ? 'New Budget Category'
                    : 'Edit Category',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Presets List (Only show when adding)
              if (widget.category == null) ...[
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _presets.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final preset = _presets[index];
                      return ActionChip(
                        avatar: Icon(
                          preset.icon,
                          size: 16,
                          color: preset.color,
                        ),
                        label: Text(preset.name),
                        onPressed: () {
                          setState(() {
                            _nameController.text = preset.name;
                            _selectedIcon = preset.icon;
                            _selectedColor = preset.color;
                          });
                        },
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Icon & Color Preview
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _showIconPicker(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _selectedColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _selectedIcon,
                        color: _selectedColor,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Icon & Color',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap the box to change icon or select a color below.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Color Picker (Horizontal)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colorOptions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final color = _colorOptions[index];
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Type Selector
              Text(
                'Category Type',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<BudgetCategoryType>(
                segments: const [
                  ButtonSegment<BudgetCategoryType>(
                    value: BudgetCategoryType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.outbound),
                  ),
                  ButtonSegment<BudgetCategoryType>(
                    value: BudgetCategoryType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.call_received),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<BudgetCategoryType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                    // Auto-adjust color if it's still default or based on type
                    if (_selectedType == BudgetCategoryType.income &&
                        _selectedColor == Colors.grey) {
                      _selectedColor = Colors.green;
                    } else if (_selectedType == BudgetCategoryType.expense &&
                        _selectedColor == Colors.green) {
                      // Maybe keep it or change to something else if we want
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                autofocus: widget.category == null,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                validator: (value) => ValidationUtils.validateRequired(
                  value,
                  'Category Name',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _limitController,
                decoration: InputDecoration(
                  labelText: _selectedType == BudgetCategoryType.income
                      ? 'Target Amount'
                      : 'Limit Amount',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                validator: ValidationUtils.validateAmount,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(
                  widget.category == null ? 'Create Category' : 'Save Changes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose an Icon',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: _iconOptions.length,
                itemBuilder: (context, index) {
                  final icon = _iconOptions[index];
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedIcon = icon);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: _selectedColor),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
