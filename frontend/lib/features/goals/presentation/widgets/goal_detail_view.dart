import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../core/theme/llc_theme.dart';
import '../../../../core/theme/refractive_glass.dart';
import '../../models/goal.dart';
import '../../models/sub_goal.dart';
import '../../repositories/goal_repository.dart';
import '../../../accounts/bloc/account_bloc.dart';
import '../../../dashboard/presentation/widgets/sub_goal_distribution_sheet.dart';

class GoalDetailView extends StatefulWidget {
  final Goal goal;
  final VoidCallback? onUpdate;
  final VoidCallback? onDelete;

  const GoalDetailView({
    super.key,
    required this.goal,
    this.onUpdate,
    this.onDelete,
  });

  @override
  State<GoalDetailView> createState() => _GoalDetailViewState();
}

class _GoalDetailViewState extends State<GoalDetailView> {
  late final GoalRepository _goalRepository;
  late Goal _currentGoal;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _goalRepository = GoalRepository(client: context.read<ApiClient>());
    _currentGoal = widget.goal;
    _refreshGoal();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(GoalDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goal.id != oldWidget.goal.id) {
      _currentGoal = widget.goal;
      _refreshGoal();
    }
  }

  Future<void> _refreshGoal() async {
    final oldGoal = _currentGoal;
    setState(() => _isLoading = true);
    try {
      final goals = await _goalRepository.getGoals();
      final updatedGoal = goals.firstWhere((g) => g.id == oldGoal.id);

      setState(() {
        _currentGoal = updatedGoal;
        _isLoading = false;
      });
      widget.onUpdate?.call();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error refreshing: $e')));
      }
    }
  }

  void _showAddSubGoal() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Subgoal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Subgoal Name (e.g., Apple Pencil)',
              ),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Target Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text;
              final amount = double.tryParse(amountController.text);
              if (name.isNotEmpty && amount != null) {
                await _goalRepository.addSubGoal(_currentGoal.id, name, amount);
                if (context.mounted) {
                  Navigator.pop(context);
                  _refreshGoal();
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditSubGoalAmount(SubGoal subGoal) {
    final amountController = TextEditingController(
      text: subGoal.currentAmount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${subGoal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current Progress: \$${subGoal.currentAmount.toStringAsFixed(2)} / \$${subGoal.targetAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'New Current Amount',
                prefixText: '\$',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newAmount = double.tryParse(amountController.text);
              if (newAmount != null) {
                await _goalRepository.updateSubGoalAmount(
                  subGoal.id,
                  newAmount,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _refreshGoal();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showManualFundGoal() {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fund ${_currentGoal.name}'),
        content: TextField(
          controller: amountController,
          decoration: const InputDecoration(
            labelText: 'Amount to Add',
            prefixText: '\$',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                if (_currentGoal.subGoals.isNotEmpty) {
                  _showSubGoalDistribution(amount);
                } else {
                  _applyManualFunding(amount, {});
                }
              }
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  void _showSubGoalDistribution(double amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SubGoalDistributionSheet(
        goal: _currentGoal,
        amount: amount,
        onConfirm: (distribution) {
          Navigator.pop(context);
          _applyManualFunding(amount, distribution);
        },
      ),
    );
  }

  Future<void> _applyManualFunding(
    double totalAmount,
    Map<String, double> distribution,
  ) async {
    setState(() => _isLoading = true);
    try {
      if (distribution.isNotEmpty) {
        for (var entry in distribution.entries) {
          final sg = _currentGoal.subGoals.firstWhere((s) => s.id == entry.key);
          await _goalRepository.updateSubGoalAmount(
            sg.id,
            sg.currentAmount + entry.value,
          );
        }
      } else {
        await _goalRepository.updateGoalCurrentAmount(
          _currentGoal.id,
          _currentGoal.currentAmount + totalAmount,
        );
      }

      await _goalRepository.insertAllocation(_currentGoal.id, totalAmount);
      await _refreshGoal();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal successfully funded!')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error funding goal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentGoal.targetAmount > 0
        ? _currentGoal.currentAmount / _currentGoal.targetAmount
        : 0.0;

    return Column(
      children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      _currentGoal.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _refreshGoal,
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Goal'),
                              content: Text(
                                'Are you sure you want to delete "${_currentGoal.name}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await _goalRepository.deleteGoal(
                                      _currentGoal.id,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      widget.onDelete?.call();
                                    }
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshGoal,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildParentProgressCard(progress),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Line Items (Subgoals)',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_currentGoal.accountIds.isEmpty)
                            IconButton(
                              onPressed: _showAddSubGoal,
                              icon: const Icon(Icons.add_circle_outline),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_currentGoal.accountIds.isNotEmpty)
                        BlocBuilder<AccountBloc, AccountState>(
                          builder: (context, state) {
                            if (state is AccountLoaded) {
                              final linkedAccounts = state.accounts
                                  .where(
                                    (a) =>
                                        _currentGoal.accountIds.contains(a.id),
                                  )
                                  .toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8, bottom: 8),
                                    child: Text(
                                      'Linked Accounts:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  ...linkedAccounts.map(
                                    (a) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.account_balance_wallet,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(a.name),
                                          const Spacer(),
                                          Text(
                                            '\$${a.balance.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      if (_currentGoal.subGoals.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'No subgoals yet. Breakdown your goal into line items!',
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _currentGoal.subGoals.length,
                          itemBuilder: (context, index) {
                            return _buildSubGoalItem(
                              _currentGoal.subGoals[index],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
  }

  Widget _buildParentProgressCard(double progress) {
    final isCompleted = _currentGoal.isCompleted;
    final colorScheme = Theme.of(context).colorScheme;
    final progressColor = isCompleted ? LLCColors.affirmMint : colorScheme.primary;

    return RefractiveGlass(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overall Progress',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: LLCColors.affirmMint.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: LLCColors.affirmMint.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: LLCColors.affirmMint, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Completed',
                              style: TextStyle(
                                color: LLCColors.affirmMint,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_currentGoal.accountIds.isNotEmpty) ...[
                      if (isCompleted) const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync, color: colorScheme.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Synced',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${_currentGoal.currentAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'Target: \$${_currentGoal.targetAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: progressColor,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% Complete',
              style: TextStyle(
                color: progressColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_currentGoal.accountIds.isEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _showManualFundGoal,
                  icon: const Icon(Icons.add_card),
                  label: const Text('Fund Goal'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isCompleted ? LLCColors.affirmMint : colorScheme.primary,
                    foregroundColor: isCompleted ? LLCColors.voidBlack : colorScheme.onPrimary,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: colorScheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Synced with Account Balances',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubGoalItem(SubGoal subGoal) {
    final subProgress = subGoal.targetAmount > 0
        ? subGoal.currentAmount / subGoal.targetAmount
        : 0.0;
    final isCompleted = subGoal.isCompleted;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RefractiveGlass(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            subGoal.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: LLCColors.affirmMint,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_currentGoal.accountIds.isEmpty)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showEditSubGoalAmount(subGoal),
                          tooltip: 'Edit Amount',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            await _goalRepository.deleteSubGoal(subGoal.id);
                            _refreshGoal();
                          },
                          tooltip: 'Delete Subgoal',
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${subGoal.currentAmount.toStringAsFixed(2)} of \$${subGoal.targetAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isCompleted ? LLCColors.affirmMint : null,
                      fontWeight: isCompleted ? FontWeight.bold : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text('${(subProgress * 100).toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: subProgress.clamp(0.0, 1.0),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: isCompleted ? LLCColors.affirmMint : null,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
