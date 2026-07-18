import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/breakpoints.dart';
import '../../../../core/theme/refractive_glass.dart';
import '../../../../core/theme/thermal_glow.dart';
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
  late final GoalRepository _goalRepository;
  List<Goal> _goals = [];
  bool _isLoading = true;
  Goal? _selectedGoal;

  @override
  void initState() {
    super.initState();
    _goalRepository = GoalRepository(client: context.read<ApiClient>());
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
        onSave: (name, amount, type, category, targetDate, accountIds) async {
          await _goalRepository.addGoal(
            name,
            amount,
            type,
            category: category,
            targetDate: targetDate,
            accountIds: accountIds,
          );
          _loadGoals();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: context.isCompact
          ? AppBar(
              title: const Text('Financial Goals'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.trending_up),
                  onPressed: () => context.push('/goals/overtime'),
                  tooltip: 'Overtime Accelerator',
                ),
              ],
            )
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 1 + (_goals.isEmpty ? 1 : _goals.length),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ThermalGlow(
              onTap: () => context.push('/goals/overtime'),
              child: RefractiveGlass(
                child: ListTile(
                  leading: Icon(
                    Icons.trending_up,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text(
                    'Overtime Accelerator',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Simulate how extra hours accelerate your goal completion',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          );
        }

        if (_goals.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No goals yet. Add one to start saving!',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final goal = _goals[index - 1];
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
