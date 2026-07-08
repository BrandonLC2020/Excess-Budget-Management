import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/llc_theme.dart';
import '../../../../core/theme/refractive_glass.dart';
import '../../../../core/theme/thermal_glow.dart';
import '../../bloc/dashboard_bloc.dart';
import '../../bloc/dashboard_event.dart';
import '../../models/allocation.dart';
import '../widgets/sub_goal_distribution_sheet.dart';
import '../../../goals/models/goal.dart';

class AllocationCard extends StatefulWidget {
  final Allocation allocation;
  final List<Goal> goals;
  final int index;

  const AllocationCard({
    super.key,
    required this.allocation,
    required this.goals,
    required this.index,
  });

  @override
  State<AllocationCard> createState() => _AllocationCardState();
}

class _AllocationCardState extends State<AllocationCard> {
  void _handleAccept(BuildContext context) {
    if (widget.allocation.type == 'goal') {
      final goal = widget.goals.firstWhere((g) => g.id == widget.allocation.id);
      if (goal.subGoals.isNotEmpty) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => SubGoalDistributionSheet(
            goal: goal,
            amount: widget.allocation.amount,
            onConfirm: (distribution) {
              Navigator.pop(context);
              context.read<DashboardBloc>().add(
                AcceptSuggestionRequested(
                  widget.allocation,
                  subGoalDistribution: distribution,
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Distributed and accepted allocation for ${widget.allocation.name}',
                  ),
                ),
              );
            },
          ),
        );
        return;
      }
    }

    // Default fallback for accounts or flat goals
    context.read<DashboardBloc>().add(
      AcceptSuggestionRequested(widget.allocation),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accepted allocation for ${widget.allocation.name}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGoal = widget.allocation.type == 'goal';
    final icon = isGoal
        ? Icons.flag_rounded
        : Icons.account_balance_wallet_rounded;
    final color = Theme.of(context).colorScheme.primary;

    Goal? targetGoal;
    if (isGoal) {
      try {
        targetGoal = widget.goals.firstWhere(
          (g) => g.id == widget.allocation.id,
        );
      } catch (_) {
        targetGoal = null;
      }
    }
    final isCompleted = targetGoal?.isCompleted ?? false;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (widget.index * 150)),
      curve: Curves.easeOutQuart,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: RefractiveGlass(
        borderRadius: 20,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.allocation.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle,
                                  color: LLCColors.affirmMint,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '\$${widget.allocation.amount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGoal ? 'Savings Goal' : 'Account Deposit',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.allocation.reason,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ThermalGlow(
                        borderRadius: 12,
                        onTap: () => _handleAccept(context),
                        child: OutlinedButton.icon(
                          onPressed: () => _handleAccept(context),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: const Text('Accept Suggestion'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: color,
                            side: BorderSide(
                              color: color.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
