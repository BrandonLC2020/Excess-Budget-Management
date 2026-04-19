import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/breakpoints.dart';
import '../../../../core/widgets/master_detail_layout.dart';
import '../../models/goal.dart';
import '../../repositories/goal_repository.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_detail_view.dart';
import '../widgets/goal_form_sheet.dart';
import 'goal_detail_screen.dart';

class GoalListScreen extends StatefulWidget {
  const GoalListScreen({super.key});

  @override
  State<GoalListScreen> createState() => _GoalListScreenState();
}

class _GoalListScreenState extends State<GoalListScreen> {
  final GoalRepository _goalRepository = GoalRepository(
    supabase: Supabase.instance.client,
  );
  List<Goal> _goals = [];
  bool _isLoading = true;
  Goal? _selectedGoal;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final goals = await _goalRepository.getGoals();
      setState(() {
        _goals = goals;
        _isLoading = false;

        // Sync selected goal if it exists
        if (_selectedGoal != null) {
          _selectedGoal = goals.firstWhere(
            (g) => g.id == _selectedGoal!.id,
            orElse: () => _selectedGoal!,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAddGoal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => GoalFormSheet(
        onSave: (name, amount, type, category, targetDate) async {
          await _goalRepository.addGoal(
            name,
            amount,
            type,
            category: category,
            targetDate: targetDate,
          );
          _loadGoals();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          context.isCompact
              ? AppBar(title: const Text('Financial Goals'))
              : null,
      body: MasterDetailLayout(
        master: _buildMasterPane(),
        detail: _selectedGoal != null
            ? GoalDetailView(
                key: ValueKey(_selectedGoal!.id),
                goal: _selectedGoal!,
                onUpdate: () => _loadGoals(silent: true),
                onDelete: () {
                  setState(() {
                    _selectedGoal = null;
                  });
                  _loadGoals();
                },
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoal,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMasterPane() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_goals.isEmpty) {
      return const Center(
        child: Text('No goals yet. Add one to start saving!'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _goals.length,
      itemBuilder: (context, index) {
        final goal = _goals[index];
        final isSelected = _selectedGoal?.id == goal.id;

        return GoalCard(
          goal: goal,
          isSelected: isSelected,
          onTap: () async {
            if (context.isCompact) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GoalDetailScreen(goal: goal),
                ),
              );
              _loadGoals();
            } else {
              setState(() {
                _selectedGoal = goal;
              });
            }
          },
          onDelete: () async {
            await _goalRepository.deleteGoal(goal.id);
            _loadGoals();
          },
        );
      },
    );
  }
}
