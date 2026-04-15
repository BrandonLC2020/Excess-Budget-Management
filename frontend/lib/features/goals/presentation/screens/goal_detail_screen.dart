import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/goal.dart';
import '../../models/sub_goal.dart';
import '../../repositories/goal_repository.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final GoalRepository _goalRepository = GoalRepository(supabase: Supabase.instance.client);
  late Goal _currentGoal;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentGoal = widget.goal;
    _refreshGoal();
  }

  Future<void> _refreshGoal() async {
    setState(() => _isLoading = true);
    try {
      final goals = await _goalRepository.getGoals();
      setState(() {
        _currentGoal = goals.firstWhere((g) => g.id == _currentGoal.id);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error refreshing: $e')));
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
              decoration: const InputDecoration(labelText: 'Subgoal Name (e.g., Apple Pencil)'),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Target Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

  @override
  Widget build(BuildContext context) {
    final progress = _currentGoal.targetAmount > 0 
        ? _currentGoal.currentAmount / _currentGoal.targetAmount 
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentGoal.name),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshGoal,
            ),
        ],
      ),
      body: RefreshIndicator(
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: _showAddSubGoal,
                    icon: const Icon(Icons.add_circle_outline),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_currentGoal.subGoals.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No subgoals yet. Breakdown your goal into line items!'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _currentGoal.subGoals.length,
                  itemBuilder: (context, index) {
                    return _buildSubGoalItem(_currentGoal.subGoals[index]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParentProgressCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Progress',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${_currentGoal.currentAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Target: \$${_currentGoal.targetAmount.toStringAsFixed(2)}',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
            color: Theme.of(context).colorScheme.onPrimary,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% Complete',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSubGoalItem(SubGoal subGoal) {
    final subProgress = subGoal.targetAmount > 0 
        ? subGoal.currentAmount / subGoal.targetAmount 
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(subGoal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    await _goalRepository.deleteSubGoal(subGoal.id);
                    _refreshGoal();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('\$${subGoal.currentAmount.toStringAsFixed(2)} of \$${subGoal.targetAmount.toStringAsFixed(2)}'),
                Text('${(subProgress * 100).toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: subProgress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
