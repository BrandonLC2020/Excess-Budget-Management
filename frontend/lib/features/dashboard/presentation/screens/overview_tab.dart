import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confetti/confetti.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/breakpoints.dart';
import '../../bloc/dashboard_bloc.dart';
import '../../bloc/dashboard_event.dart';
import '../../bloc/dashboard_state.dart';
import '../../models/allocation.dart';
import '../widgets/allocation_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/sub_goal_distribution_sheet.dart';
import '../../../goals/models/goal.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final TextEditingController _amountController = TextEditingController();
  late ConfettiController _confettiController;
  List<Goal> _previousGoals = [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _checkGoalCompletions(List<Goal> newGoals) {
    if (_previousGoals.isEmpty) {
      _previousGoals = newGoals;
      return;
    }

    bool transitioned = false;
    for (final newGoal in newGoals) {
      final oldGoal = _previousGoals.cast<Goal?>().firstWhere(
        (g) => g?.id == newGoal.id,
        orElse: () => null,
      );

      if (oldGoal != null && !oldGoal.isCompleted && newGoal.isCompleted) {
        transitioned = true;
        break;
      }
    }

    if (transitioned) {
      _confettiController.play();
    }
    _previousGoals = newGoals;
  }

  void _analyzeFunds() {
    final val = double.tryParse(_amountController.text);
    if (val != null && val > 0) {
      context.read<DashboardBloc>().add(GenerateSuggestionsRequested(val));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
    }
  }

  void _showManualAllocation(List<Goal> goals) {
    if (goals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No goals found. Create one first!')),
      );
      return;
    }

    Goal? selectedGoal;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Manual Allocation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Goal>(
                    initialValue: selectedGoal,
                    decoration: const InputDecoration(labelText: 'Select Goal'),
                    items: goals.map((g) {
                      return DropdownMenuItem(value: g, child: Text(g.name));
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedGoal = val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: r'$',
                    ),
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
                  onPressed: () {
                    if (selectedGoal != null) {
                      final amount = double.tryParse(amountController.text);
                      if (amount != null && amount > 0) {
                        final allocation = Allocation(
                          id: selectedGoal!.id,
                          name: selectedGoal!.name,
                          amount: amount,
                          type: 'goal',
                          reason: 'Manual allocation',
                        );

                        if (selectedGoal!.subGoals.isNotEmpty) {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => SubGoalDistributionSheet(
                              goal: selectedGoal!,
                              amount: amount,
                              onConfirm: (distribution) {
                                Navigator.pop(context);
                                context.read<DashboardBloc>().add(
                                  AcceptSuggestionRequested(
                                    allocation,
                                    subGoalDistribution: distribution,
                                  ),
                                );
                              },
                            ),
                          );
                        } else {
                          context.read<DashboardBloc>().add(
                            AcceptSuggestionRequested(allocation),
                          );
                          Navigator.pop(context);
                        }
                      }
                    }
                  },
                  child: const Text('Allocate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DashboardBloc, DashboardState>(
      listener: (context, state) {
        if (state is DashboardSuggestionsLoaded) {
          _checkGoalCompletions(state.goals);
        }
      },
      builder: (context, state) {
        final List<Goal> goals = switch (state) {
          DashboardSuggestionsLoaded s => s.goals,
          DashboardDataLoaded d => d.goals,
          _ => [],
        };

        return Scaffold(
          appBar:
              context.isCompact ? AppBar(title: const Text('Overview')) : null,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go('/bulk-entry'),
            icon: const Icon(Icons.library_add),
            label: const Text('Bulk Entry'),
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  // Trigger a refresh of current amount if needed,
                  // for now we just reset or re-analyze if we have an amount
                  final val = double.tryParse(_amountController.text);
                  if (val != null && val > 0) {
                    context.read<DashboardBloc>().add(
                      GenerateSuggestionsRequested(val),
                    );
                  } else {
                    context.read<DashboardBloc>().add(
                      DashboardInitialDataRequested(),
                    );
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context),
                          const SizedBox(height: 32),
                          _buildAnalysisInput(context, goals),
                          const SizedBox(height: 32),
                          if (state is DashboardLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (state is DashboardDataLoaded) ...[
                            _buildMetrics(context, state),
                            const SizedBox(height: 32),
                          ] else if (state is DashboardSuggestionsLoaded)
                            _buildSuggestionsList(context, state)
                          else if (state is DashboardError)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Text(
                                  'Error: ${state.message}',
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            _buildEmptyState(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial Overview',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Analyze your funds and optimize your savings.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => context.push('/history'),
          icon: const Icon(Icons.history),
          tooltip: 'Allocation History',
        ),
      ],
    );
  }

  Widget _buildAnalysisInput(BuildContext context, List<Goal> goals) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Analysis',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'How much do you want to allocate?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _analyzeFunds,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size(64, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Icon(Icons.analytics_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _showManualAllocation(goals),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Perform Manual Allocation'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(
    BuildContext context,
    DashboardSuggestionsLoaded state,
  ) {
    final suggestions = state.result.allocations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Proposed Allocations',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${suggestions.length} items',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (context.isCompact) {
              return Column(
                children: suggestions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final s = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AllocationCard(
                      allocation: s,
                      goals: state.goals,
                      index: index,
                    ),
                  );
                }).toList(),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 450,
                childAspectRatio: 1.4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                return AllocationCard(
                  allocation: suggestions[index],
                  goals: state.goals,
                  index: index,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.savings_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to Grow?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter an amount above to see smart\nallocation suggestions for your goals.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(BuildContext context, DashboardDataLoaded state) {
    final netWorth = state.accounts.fold(0.0, (sum, a) => sum + a.balance);

    final totalSpent = state.budgetCategories.fold(
      0.0,
      (sum, b) => sum + b.spentAmount,
    );
    final totalLimit = state.budgetCategories.fold(
      0.0,
      (sum, b) => sum + b.limitAmount,
    );
    final budgetProgress =
        totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;

    final totalSaved = state.goals.fold(0.0, (sum, g) => sum + g.currentAmount);
    final totalTarget = state.goals.fold(0.0, (sum, g) => sum + g.targetAmount);
    final goalProgress =
        totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;

    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth > 800
                ? 3
                : (constraints.maxWidth > 600 ? 2 : 1);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            MetricCard(
              title: 'Net Worth',
              value: currencyFormat.format(netWorth),
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.blue,
            ),
            MetricCard(
              title: 'Monthly Budget',
              value:
                  '${currencyFormat.format(totalSpent)} / ${currencyFormat.format(totalLimit)}',
              icon: Icons.pie_chart_outline,
              color: Colors.orange,
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: budgetProgress,
                      minHeight: 6,
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
            MetricCard(
              title: 'Goal Progress',
              value: '${(goalProgress * 100).toStringAsFixed(0)}%',
              icon: Icons.flag_outlined,
              color: Colors.green,
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: goalProgress,
                      minHeight: 6,
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(Colors.green),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${currencyFormat.format(totalSaved)} of ${currencyFormat.format(totalTarget)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
