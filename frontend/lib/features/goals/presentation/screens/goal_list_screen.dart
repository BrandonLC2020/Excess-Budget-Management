import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/goal.dart';
import '../../repositories/goal_repository.dart';
import '../widgets/goal_form_sheet.dart';
import 'goal_detail_screen.dart';

class GoalListScreen extends StatefulWidget {
  const GoalListScreen({super.key});

  @override
  State<GoalListScreen> createState() => _GoalListScreenState();
}

class _GoalListScreenState extends State<GoalListScreen> {
  final GoalRepository _goalRepository = GoalRepository(supabase: Supabase.instance.client);
  List<Goal> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      final goals = await _goalRepository.getGoals();
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAddGoal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => GoalFormSheet(
        onSave: (name, amount, type, category, targetDate) async {
          await _goalRepository.addGoal(name, amount, type, category: category, targetDate: targetDate);
          _loadGoals();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Financial Goals')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? const Center(child: Text('No goals yet. Add one to start saving!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    final progress = goal.targetAmount > 0 
                        ? goal.currentAmount / goal.targetAmount 
                        : 0.0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GoalDetailScreen(goal: goal),
                            ),
                          );
                          _loadGoals();
                        },
                        title: Text(goal.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('\$${goal.currentAmount.toStringAsFixed(2)} of \$${goal.targetAmount.toStringAsFixed(2)}'),
                                Text(goal.category.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await _goalRepository.deleteGoal(goal.id);
                            _loadGoals();
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
