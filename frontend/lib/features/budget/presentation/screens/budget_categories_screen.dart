import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/breakpoints.dart';
import '../../bloc/budget_bloc.dart';
import '../widgets/budget_category_card.dart';
import '../widgets/budget_category_form_sheet.dart';
import '../../models/budget_category.dart';

class BudgetCategoriesScreen extends StatefulWidget {
  const BudgetCategoriesScreen({super.key});

  @override
  State<BudgetCategoriesScreen> createState() => _BudgetCategoriesScreenState();
}

class _BudgetCategoriesScreenState extends State<BudgetCategoriesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BudgetBloc>().add(LoadBudgets());
  }

  void _showCategoryForm([BudgetCategory? budgetCategory]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BudgetCategoryFormSheet(category: budgetCategory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: context.isCompact
          ? AppBar(
              title: const Text('Budget Categories'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: BlocBuilder<BudgetBloc, BudgetState>(
        builder: (context, state) {
          if (state is BudgetLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is BudgetError) {
            return Center(child: Text('Error: ${state.message}'));
          } else if (state is BudgetLoaded) {
            // Calculate totals
            double totalBudget = 0;
            double totalSpent = 0;
            for (var cat in state.categories) {
              totalBudget += cat.limitAmount;
              totalSpent += cat.spentAmount;
            }
            final overallPercent = totalBudget > 0
                ? (totalSpent / totalBudget).clamp(0.0, 1.0)
                : 0.0;

            return CustomScrollView(
              slivers: [
                // Summary Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(context).colorScheme.secondaryContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Budget Allocation',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withValues(alpha: 0.8),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '\$${totalSpent.toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                              ),
                              Text(
                                ' / \$${totalBudget.toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: overallPercent,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.3,
                              ),
                              color: overallPercent > 0.9
                                  ? Colors.redAccent
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                if (state.categories.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No categories yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to create your first budget category.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final category = state.categories[index];
                        final percent = category.limitAmount > 0
                            ? (category.spentAmount / category.limitAmount)
                                  .clamp(0.0, 1.0)
                            : 0.0;

                        return BudgetCategoryCard(
                          category: category,
                          percent: percent,
                          onTap: () => _showCategoryForm(category),
                          onDelete: () {
                            context.read<BudgetBloc>().add(
                              DeleteBudgetCategory(category.id),
                            );
                          },
                        );
                      }, childCount: state.categories.length),
                    ),
                  ),

                // Bottom padding for FAB
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          }
          return const Center(child: Text('Failed to load budget categories.'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }
}
