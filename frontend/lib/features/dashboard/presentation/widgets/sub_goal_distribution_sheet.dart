import 'package:flutter/material.dart';
import '../../../goals/models/goal.dart';

class SubGoalDistributionSheet extends StatefulWidget {
  final Goal goal;
  final double amount;
  final Function(Map<String, double> distribution) onConfirm;

  const SubGoalDistributionSheet({
    super.key,
    required this.goal,
    required this.amount,
    required this.onConfirm,
  });

  @override
  State<SubGoalDistributionSheet> createState() =>
      _SubGoalDistributionSheetState();
}

class _SubGoalDistributionSheetState extends State<SubGoalDistributionSheet> {
  final Map<String, double> _distribution = {};
  final Map<String, TextEditingController> _controllers = {};
  double _remaining = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.amount;
    for (var sg in widget.goal.subGoals) {
      _distribution[sg.id] = 0.0;
      _controllers[sg.id] = TextEditingController(text: '0.00');
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _quickFill() {
    double toDistribute = widget.amount;
    final Map<String, double> newDist = {};

    for (var sg in widget.goal.subGoals) {
      final needed = sg.targetAmount - sg.currentAmount;
      if (needed > 0) {
        final fill = toDistribute > needed ? needed : toDistribute;
        newDist[sg.id] = fill;
        toDistribute -= fill;
      } else {
        newDist[sg.id] = 0.0;
      }
      if (toDistribute <= 0) break;
    }

    // If there's still money left, put it in the last subgoal
    if (toDistribute > 0 && widget.goal.subGoals.isNotEmpty) {
      final lastId = widget.goal.subGoals.last.id;
      newDist[lastId] = (newDist[lastId] ?? 0.0) + toDistribute;
    }

    setState(() {
      for (var sg in widget.goal.subGoals) {
        final amount = newDist[sg.id] ?? 0.0;
        _distribution[sg.id] = amount;
        _controllers[sg.id]?.text = amount.toStringAsFixed(2);
      }
      _remaining = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Distribute Funds',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'How should we split \$${widget.amount.toStringAsFixed(2)} for ${widget.goal.name}?',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.goal.subGoals.length,
              itemBuilder: (context, index) {
                final sg = widget.goal.subGoals[index];
                return ListTile(
                  title: Text(sg.name),
                  subtitle: Text(
                    'Needs \$${(sg.targetAmount - sg.currentAmount).toStringAsFixed(2)}',
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _controllers[sg.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(prefixText: '\$'),
                      onChanged: (val) {
                        setState(() {
                          _distribution[sg.id] = double.tryParse(val) ?? 0.0;
                          _remaining =
                              widget.amount -
                              (_distribution.values.isNotEmpty
                                  ? _distribution.values.reduce((a, b) => a + b)
                                  : 0.0);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining: \$${_remaining.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _remaining < 0 ? Colors.red : Colors.green,
                ),
              ),
              TextButton(
                onPressed: _quickFill,
                child: const Text('Quick Fill'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _remaining.abs() < 0.001
                ? () => widget.onConfirm(_distribution)
                : null,
            child: const Text('Confirm Distribution'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
