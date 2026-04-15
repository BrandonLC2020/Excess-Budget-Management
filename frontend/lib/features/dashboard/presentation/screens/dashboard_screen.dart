import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../budget/presentation/screens/budget_categories_screen.dart';
import '../../../goals/presentation/screens/goal_list_screen.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../bloc/dashboard_bloc.dart';
import '../../bloc/dashboard_event.dart';
import '../../bloc/dashboard_state.dart';
import '../../models/allocation.dart';
import '../widgets/sub_goal_distribution_sheet.dart';
import '../../../goals/models/goal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _OverviewTab(),
    const AccountsScreen(),
    const BudgetCategoriesScreen(),
    const GoalListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Goals',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final TextEditingController _amountController = TextEditingController();

  void _analyzeFunds() {
    final val = double.tryParse(_amountController.text);
    if (val != null && val > 0) {
      context.read<DashboardBloc>().add(GenerateSuggestionsRequested(val));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Month-End Review', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'AI Allocation Strategy',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your excess funds the AI will analyze your accounts and goals to find the best distribution.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 32),
                      _buildInputCard(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                sliver: BlocBuilder<DashboardBloc, DashboardState>(
                  builder: (context, state) {
                    if (state is DashboardInitial) {
                      return SliverToBoxAdapter(child: const SizedBox.shrink());
                    } else if (state is DashboardLoading) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    } else if (state is DashboardError) {
                      return SliverToBoxAdapter(
                        child: Text(
                          state.message,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      );
                    } else if (state is DashboardSuggestionsLoaded) {
                      final allocations = state.result.allocations;
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _AllocationCard(
                                allocation: allocations[index],
                                goals: state.goals,
                                index: index,
                              ),
                            );
                          },
                          childCount: allocations.length,
                        ),
                      );
                    }
                    return SliverToBoxAdapter(child: const SizedBox.shrink());
                  },
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 48)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.attach_money, color: Theme.of(context).colorScheme.primary),
                    labelText: 'Excess Funds Amount',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _analyzeFunds,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'Analyze with AI',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  final Allocation allocation;
  final List<Goal> goals;
  final int index;

  const _AllocationCard({
    required this.allocation,
    required this.goals,
    required this.index,
  });

  void _handleAccept(BuildContext context) {
    if (allocation.type == 'goal') {
      final goal = goals.firstWhere((g) => g.id == allocation.id);
      if (goal.subGoals.isNotEmpty) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => SubGoalDistributionSheet(
            goal: goal,
            amount: allocation.amount,
            onConfirm: (distribution) {
              Navigator.pop(context);
              context.read<DashboardBloc>().add(
                    AcceptSuggestionRequested(
                      allocation,
                      subGoalDistribution: distribution,
                    ),
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Distributed and accepted allocation for ${allocation.name}')),
              );
            },
          ),
        );
        return;
      }
    }

    // Default fallback for accounts or flat goals
    context.read<DashboardBloc>().add(AcceptSuggestionRequested(allocation));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Accepted allocation for ${allocation.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGoal = allocation.type == 'goal';
    final icon = isGoal ? Icons.flag_rounded : Icons.account_balance_wallet_rounded;
    final color = isGoal ? Colors.purpleAccent.shade400 : Theme.of(context).colorScheme.primary;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 150)),
      curve: Curves.easeOutQuart,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
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
                          child: Text(
                            allocation.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '\$${allocation.amount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGoal ? 'Savings Goal' : 'Account Deposit',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      allocation.reason,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleAccept(context),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Accept Suggestion'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
