import 'package:flutter/material.dart';
import '../../../../core/breakpoints.dart';
import '../../models/goal.dart';

class GoalCard extends StatefulWidget {
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
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final progress = widget.goal.targetAmount > 0
        ? widget.goal.currentAmount / widget.goal.targetAmount
        : 0.0;
    final isCompleted = widget.goal.isCompleted;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.04),
              blurRadius: _isHovered ? 12 : 4,
              offset: Offset(0, _isHovered ? 6 : 2),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: !context.isCompact && widget.isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _isHovered
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
          child: ListTile(
            onTap: widget.onTap,
            hoverColor: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.1),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.goal.name,
                    style: TextStyle(
                      fontWeight: widget.isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (isCompleted) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 16,
                  ),
                ],
                if (widget.goal.accountIds.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Synced with Account',
                    child: Icon(
                      Icons.sync,
                      color: Theme.of(context).colorScheme.primary,
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
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: isCompleted ? Colors.green : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${widget.goal.currentAmount.toStringAsFixed(2)} of \$${widget.goal.targetAmount.toStringAsFixed(2)}',
                    ),
                    Text(
                      widget.goal.category.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            trailing: context.isCompact
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: widget.onDelete,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
