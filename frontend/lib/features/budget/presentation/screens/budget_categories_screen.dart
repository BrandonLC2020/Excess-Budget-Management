import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../bloc/budget_bloc.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget Categories')),
      body: BlocBuilder<BudgetBloc, BudgetState>(
        builder: (context, state) {
          if (state is BudgetLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is BudgetError) {
            return Center(child: Text('Error: ${state.message}'));
          } else if (state is BudgetLoaded) {
            if (state.categories.isEmpty) {
              return const Center(child: Text('No categories found. Add one!'));
            }
            return ListView.builder(
              itemCount: state.categories.length,
              itemBuilder: (context, index) {
                final category = state.categories[index];
                final percent = category.limitAmount > 0 
                    ? (category.spentAmount / category.limitAmount).clamp(0.0, 1.0)
                    : 0.0;
                
                return ListTile(
                  title: Text(category.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('\$${category.spentAmount.toStringAsFixed(2)} / \$${category.limitAmount.toStringAsFixed(2)}'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percent,
                        backgroundColor: Colors.grey[200],
                        color: percent >= 1.0 ? Colors.red : Colors.green,
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      context.read<BudgetBloc>().add(DeleteBudgetCategory(category.id));
                    },
                  ),
                  onTap: () => context.push('/budget/edit', extra: category),
                );
              },
            );
          }
          return const Center(child: Text('Failed to load budget categories.'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/budget/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
