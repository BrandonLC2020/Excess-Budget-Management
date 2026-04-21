import 'package:flutter/material.dart';
import '../../models/goal.dart';
import '../widgets/goal_detail_view.dart';

class GoalDetailScreen extends StatelessWidget {
  final Goal goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(goal.name)),
      body: GoalDetailView(goal: goal, onDelete: () => Navigator.pop(context)),
    );
  }
}
