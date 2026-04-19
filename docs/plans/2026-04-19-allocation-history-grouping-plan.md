# Allocation History Grouping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modify the `AllocationHistoryBloc` and `AllocationHistoryScreen` to flatten and group raw allocations by month, inserting header objects into the list for display.

**Architecture:** We will create a sealed class `AllocationListItem` inside `allocation_history_state.dart`. The bloc will process `List<GoalAllocation>` into `List<AllocationListItem>`. The UI will iterate over this new list, displaying a header widget or the existing allocation card.

**Tech Stack:** Flutter, flutter_bloc, intl

---

### Task 1: Define `AllocationListItem` and update State

**Files:**
- Modify: `frontend/lib/features/goals/bloc/allocation_history_state.dart`
- Test: `frontend/test/features/goals/bloc/allocation_history_state_test.dart` (Create if needed, but simple states can just be verified via bloc test).

- [ ] **Step 1: Write/Update tests to expect the new State model**
```dart
// frontend/test/features/goals/bloc/allocation_history_bloc_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:excess_budget_management/features/goals/bloc/allocation_history_bloc.dart';
import 'package:excess_budget_management/features/goals/bloc/allocation_history_event.dart';
import 'package:excess_budget_management/features/goals/bloc/allocation_history_state.dart';
import 'package:excess_budget_management/features/goals/models/allocation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:excess_budget_management/features/goals/repositories/goal_repository.dart';

class MockGoalRepository extends Mock implements GoalRepository {}

void main() {
  late MockGoalRepository mockRepo;
  late AllocationHistoryBloc bloc;

  setUp(() {
    mockRepo = MockGoalRepository();
    bloc = AllocationHistoryBloc(goalRepository: mockRepo);
  });

  tearDown(() {
    bloc.close();
  });

  blocTest<AllocationHistoryBloc, AllocationHistoryState>(
    'emits Loading then Loaded with grouped items',
    build: () {
      when(() => mockRepo.getAllocations()).thenAnswer((_) async => [
            GoalAllocation(id: '1', userId: 'u1', goalId: 'g1', amount: 10, createdAt: DateTime(2026, 4, 15)),
            GoalAllocation(id: '2', userId: 'u1', goalId: 'g2', amount: 20, createdAt: DateTime(2026, 3, 10)),
          ]);
      return bloc;
    },
    act: (bloc) => bloc.add(FetchAllocationHistory()),
    expect: () => [
      isA<AllocationHistoryLoading>(),
      isA<AllocationHistoryLoaded>().having(
        (s) => s.items.length, 
        'contains 2 headers and 2 items', 
        4,
      ),
    ],
  );
}
```

- [ ] **Step 2: Run test to verify failure**
Run: `cd frontend && flutter test test/features/goals/bloc/allocation_history_bloc_test.dart`
Expected: Failure or compilation error because `items` is not in `AllocationHistoryLoaded`.

- [ ] **Step 3: Define `AllocationListItem` and update `AllocationHistoryLoaded`**
```dart
// frontend/lib/features/goals/bloc/allocation_history_state.dart
import '../models/allocation.dart';

sealed class AllocationListItem {}

class AllocationMonthHeader extends AllocationListItem {
  final String monthYear;
  AllocationMonthHeader(this.monthYear);
}

class AllocationItem extends AllocationListItem {
  final GoalAllocation allocation;
  AllocationItem(this.allocation);
}

abstract class AllocationHistoryState {}

class AllocationHistoryInitial extends AllocationHistoryState {}

class AllocationHistoryLoading extends AllocationHistoryState {}

class AllocationHistoryLoaded extends AllocationHistoryState {
  final List<AllocationListItem> items;

  AllocationHistoryLoaded(this.items);
}

class AllocationHistoryError extends AllocationHistoryState {
  final String message;

  AllocationHistoryError(this.message);
}
```

- [ ] **Step 4: Update the Bloc to process groupings**
```dart
// frontend/lib/features/goals/bloc/allocation_history_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../repositories/goal_repository.dart';
import 'allocation_history_event.dart';
import 'allocation_history_state.dart';

class AllocationHistoryBloc
    extends Bloc<AllocationHistoryEvent, AllocationHistoryState> {
  final GoalRepository goalRepository;

  AllocationHistoryBloc({required this.goalRepository})
      : super(AllocationHistoryInitial()) {
    on<FetchAllocationHistory>((event, emit) async {
      emit(AllocationHistoryLoading());
      try {
        final allocations = await goalRepository.getAllocations();
        
        final List<AllocationListItem> groupedItems = [];
        String? currentMonth;
        
        for (final allocation in allocations) {
          final monthStr = DateFormat('MMMM yyyy').format(allocation.createdAt);
          if (monthStr != currentMonth) {
            groupedItems.add(AllocationMonthHeader(monthStr));
            currentMonth = monthStr;
          }
          groupedItems.add(AllocationItem(allocation));
        }

        emit(AllocationHistoryLoaded(groupedItems));
      } catch (e) {
        emit(AllocationHistoryError(e.toString()));
      }
    });
  }
}
```

- [ ] **Step 5: Run tests and confirm they pass**
Run: `cd frontend && flutter test test/features/goals/bloc/allocation_history_bloc_test.dart`
Expected: PASS. If compilation fails in UI files, that's expected. We fix UI in the next step.

- [ ] **Step 6: Commit state and bloc changes**
```bash
git add frontend/lib/features/goals/bloc/ frontend/test/features/goals/bloc/
git commit -m "feat(goals): add AllocationListItem sealed class and grouping logic to bloc"
```

### Task 2: Update Allocation History Screen

**Files:**
- Modify: `frontend/lib/features/goals/presentation/screens/allocation_history_screen.dart`

- [ ] **Step 1: Update the screen to handle `AllocationListItem`**
```dart
// frontend/lib/features/goals/presentation/screens/allocation_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/allocation_history_bloc.dart';
import '../../bloc/allocation_history_event.dart';
import '../../bloc/allocation_history_state.dart';

class AllocationHistoryScreen extends StatelessWidget {
  const AllocationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allocation History'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: BlocBuilder<AllocationHistoryBloc, AllocationHistoryState>(
        builder: (context, state) {
          if (state is AllocationHistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AllocationHistoryError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${state.message}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<AllocationHistoryBloc>().add(
                          FetchAllocationHistory(),
                        );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is AllocationHistoryLoaded) {
            final items = state.items;
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 80,
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No allocations yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final listItem = items[index];

                if (listItem is AllocationMonthHeader) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 8.0),
                    child: Text(
                      listItem.monthYear,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  );
                } else if (listItem is AllocationItem) {
                  final item = listItem.allocation;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.add),
                        ),
                        title: Text(
                          item.goalName ?? 'Unknown Goal',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          DateFormat('MMM d, yyyy • h:mm a').format(item.createdAt),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: Text(
                          NumberFormat.currency(symbol: r'$').format(item.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Run Flutter Analyzer & Tests**
Run: `cd frontend && dart format . && dart analyze && flutter test`
Expected: 0 Issues, All Tests PASS.

- [ ] **Step 3: Commit UI changes**
```bash
git add frontend/lib/features/goals/presentation/screens/allocation_history_screen.dart
git commit -m "feat(goals): display grouped allocation history by month"
```
