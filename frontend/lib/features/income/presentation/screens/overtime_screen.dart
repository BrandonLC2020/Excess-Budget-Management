import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/breakpoints.dart';
import '../../../../core/utils/optional.dart';
import '../../goals/models/goal.dart';
import '../../goals/models/sub_goal.dart';
import '../../income/bloc/overtime_bloc.dart';
import '../../income/models/overtime_settings.dart';

class OvertimeScreen extends StatefulWidget {
  const OvertimeScreen({super.key});

  @override
  State<OvertimeScreen> createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> {
  final _baseWageController = TextEditingController();
  final _multiplierController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _standardContribController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _baseWageController.dispose();
    _multiplierController.dispose();
    _taxRateController.dispose();
    _standardContribController.dispose();
    super.dispose();
  }

  void _initFields(OvertimeSettings settings) {
    _baseWageController.text = settings.hourlyBaseRate.toStringAsFixed(2);
    _multiplierController.text = settings.overtimeMultiplier.toStringAsFixed(2);
    _taxRateController.text = settings.estimatedTaxRate.toStringAsFixed(2);
    _initialized = true;
  }

  void _onFieldChanged() {
    final base = double.tryParse(_baseWageController.text) ?? 0.0;
    final mult = double.tryParse(_multiplierController.text) ?? 1.5;
    final tax = double.tryParse(_taxRateController.text) ?? 0.25;

    context.read<OvertimeBloc>().add(
          UpdateOvertimeSettingsField(
            hourlyBaseRate: base,
            overtimeMultiplier: mult,
            estimatedTaxRate: tax,
          ),
        );
  }

  void _onStandardContribChanged() {
    final contrib = double.tryParse(_standardContribController.text) ?? 0.0;
    context.read<OvertimeBloc>().add(UpdateStandardContribution(contrib));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<OvertimeBloc, OvertimeState>(
      listenWhen: (prev, curr) => !prev.isLoading && curr.settings != null && !_initialized,
      listener: (context, state) {
        if (state.settings != null) {
          _initFields(state.settings!);
          _standardContribController.text = state.standardContribution.toStringAsFixed(2);
        }
      },
      child: BlocBuilder<OvertimeBloc, OvertimeState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.settings != null && !_initialized) {
            _initFields(state.settings!);
            _standardContribController.text = state.standardContribution.toStringAsFixed(2);
          }

          final selectedGoal = state.goals.where((g) => g.id == state.selectedGoalId).firstOrNull;
          final subgoals = selectedGoal?.subGoals ?? [];
          final selectedSubgoal = subgoals.where((s) => s.id == state.selectedSubgoalId).firstOrNull;

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  key: const ValueKey('error_message'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: TextStyle(color: theme.colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (context.isCompact) ...[
                _buildFormCard(context, state, selectedGoal, subgoals, selectedSubgoal),
                const SizedBox(height: 16),
                _buildProjectionCard(context, state, selectedGoal, selectedSubgoal),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildFormCard(context, state, selectedGoal, subgoals, selectedSubgoal),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: _buildProjectionCard(context, state, selectedGoal, selectedSubgoal),
                    ),
                  ],
                ),
            ],
          );

          return Scaffold(
            appBar: AppBar(
              title: const Text('Overtime Accelerator'),
              actions: [
                if (state.isSaving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: state.settings == null
                        ? null
                        : () {
                            context.read<OvertimeBloc>().add(SaveOvertimeSettings());
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Settings saved successfully.')),
                            );
                          },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                  ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: content,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    OvertimeState state,
    Goal? selectedGoal,
    List<SubGoal> subgoals,
    SubGoal? selectedSubgoal,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Earnings Profile',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _baseWageController,
                    decoration: const InputDecoration(
                      labelText: 'Base Hourly Rate',
                      prefixText: '$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _onFieldChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _multiplierController,
                    decoration: const InputDecoration(
                      labelText: 'Multiplier',
                      suffixText: 'x',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _onFieldChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _taxRateController,
              decoration: const InputDecoration(
                labelText: 'Estimated Marginal Tax Rate (0.00 to 1.00)',
                suffixIcon: Icon(Icons.percent),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _onFieldChanged(),
            ),
            const Divider(height: 32),
            Text(
              'Target Allocation',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: state.selectedGoalId,
              decoration: const InputDecoration(
                labelText: 'Select Financial Goal',
                border: OutlineInputBorder(),
              ),
              items: state.goals.map((g) {
                return DropdownMenuItem<String>(
                  value: g.id,
                  child: Text(g.name),
                );
              }).toList(),
              onChanged: (val) {
                context.read<OvertimeBloc>().add(
                      SelectGoalOrSubgoal(goalId: val, subgoalId: null),
                    );
              },
            ),
            if (subgoals.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: state.selectedSubgoalId,
                decoration: const InputDecoration(
                  labelText: 'Select Subgoal (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Entire Goal (Aggregate)'),
                  ),
                  ...subgoals.map((s) {
                    return DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(s.name),
                    );
                  }),
                ],
                onChanged: (val) {
                  context.read<OvertimeBloc>().add(
                        SelectGoalOrSubgoal(goalId: state.selectedGoalId, subgoalId: val),
                      );
                },
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _standardContribController,
              decoration: const InputDecoration(
                labelText: 'Standard Monthly Savings Contribution',
                prefixText: '$',
                border: OutlineInputBorder(),
                helperText: 'How much do you save towards this goal without overtime?',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _onStandardContribChanged(),
            ),
            const Divider(height: 32),
            Text(
              'Proposed Overtime Hours',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${state.overtimeHoursPerWeek.toStringAsFixed(1)} hrs / week',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '~ ${(state.overtimeHoursPerWeek * 4.33).toStringAsFixed(1)} hrs / month',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            Slider(
              value: state.overtimeHoursPerWeek,
              min: 0,
              max: 40,
              divisions: 80,
              label: '${state.overtimeHoursPerWeek.toStringAsFixed(1)} hrs',
              onChanged: (val) {
                context.read<OvertimeBloc>().add(UpdateOvertimeHours(val));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionCard(
    BuildContext context,
    OvertimeState state,
    Goal? selectedGoal,
    SubGoal? selectedSubgoal,
  ) {
    final theme = Theme.of(context);
    final proj = state.projection;

    if (proj == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        child: const Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(
            child: Text('Adjust settings or select a goal to see projections.'),
          ),
        ),
      );
    }

    final hasTarget = selectedGoal != null;
    final targetName = selectedSubgoal != null ? '${selectedGoal!.name} → ${selectedSubgoal.name}' : (selectedGoal?.name ?? '');
    final remainingAmount = selectedSubgoal != null
        ? (selectedSubgoal.targetAmount - selectedSubgoal.currentAmount)
        : (selectedGoal?.targetAmount ?? 0.0) - (selectedGoal?.currentAmount ?? 0.0);
    final targetString = remainingAmount > 0 ? '\$${remainingAmount.toStringAsFixed(2)} remaining' : 'Fully Funded';

    return Column(
      children: [
        // Rate Card
        Card(
          elevation: 0,
          color: theme.colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 40,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Overtime Hourly Rate',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        '\$${proj.netHourlyRate.toStringAsFixed(2)} / hr',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Income Projections Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overtime Earnings Impact',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildStatRow(context, 'Weekly Net Increase', '+\$${proj.weeklyOvertimeNetIncome.toStringAsFixed(2)}'),
                const Divider(),
                _buildStatRow(context, 'Monthly Net Increase', '+\$${proj.monthlyOvertimeNetIncome.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Timeline Projections Card (Only if a goal/subgoal is selected)
        if (hasTarget)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetName,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              targetString,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (proj.monthsSaved != null && proj.monthsSaved! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: BorderSide(color: Colors.green.shade200),
                          ),
                          child: Text(
                            '${proj.monthsSaved!.toStringAsFixed(1)} mos saved',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  if (proj.totalHoursNeeded != null && proj.totalHoursNeeded! > 0) ...[
                    Text(
                      'Psychological Goal Target',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                        children: [
                          const TextSpan(text: 'It will take '),
                          TextSpan(
                            text: '${proj.totalHoursNeeded!.toStringAsFixed(1)} hours',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: ' of overtime to fully fund the remaining balance.'),
                        ],
                      ),
                    ),
                    const Divider(height: 32),
                  ],
                  Text(
                    'Time to Complete',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (proj.monthsToCompleteStandard != null) ...[
                    _buildTimelineBar(
                      context,
                      'Standard Savings Path',
                      proj.monthsToCompleteStandard!,
                      theme.colorScheme.secondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (proj.monthsToCompleteWithOvertime != null)
                    _buildTimelineBar(
                      context,
                      'Overtime Accelerated Path',
                      proj.monthsToCompleteWithOvertime!,
                      theme.colorScheme.primary,
                    ),
                  if (proj.monthsToCompleteStandard == null && proj.monthsToCompleteWithOvertime == null)
                    const Text('Enter hours or standard contribution to estimate timeline.'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTimelineBar(BuildContext context, String label, double months, Color color) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text(
              '${months.toStringAsFixed(1)} ${months == 1.0 ? 'month' : 'months'}',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            width: double.infinity,
            color: theme.colorScheme.surfaceVariant,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              // Normalize: cap bar representation at 1.0. Let's assume max is 24 months for bar sizing.
              widthFactor: (months / 24.0).clamp(0.01, 1.0),
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}
