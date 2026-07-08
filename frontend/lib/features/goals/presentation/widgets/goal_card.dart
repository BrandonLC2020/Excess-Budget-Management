import 'package:flutter/material.dart';
import '../../../../core/breakpoints.dart';
import '../../../../core/theme/llc_theme.dart';
import '../../../../core/theme/refractive_glass.dart';
import '../../../../core/theme/thermal_glow.dart';
import '../../models/goal.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const GoalCard({
    super.key,
    required this.goal,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal.targetAmount > 0
        ? goal.currentAmount / goal.targetAmount
        : 0.0;
    final isCompleted = goal.isCompleted;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ThermalGlow(
        onTap: onTap,
        child: RefractiveGlass(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: !context.isCompact && isSelected
                  ? Border.all(color: colorScheme.primary, width: 1.5)
                  : null,
            ),
            child: ListTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isCompleted) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.check_circle,
                      color: LLCColors.affirmMint,
                      size: 16,
                    ),
                  ],
                  if (goal.accountIds.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Synced with Account',
                      child: Icon(
                        Icons.sync,
                        color: colorScheme.primary,
                        size: 16,
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: isCompleted ? LLCColors.affirmMint : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${goal.currentAmount.toStringAsFixed(2)} of \$${goal.targetAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        goal.category.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
              trailing: context.isCompact
                  ? IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: onDelete,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
