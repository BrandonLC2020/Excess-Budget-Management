import 'package:flutter_bloc/flutter_bloc.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';
import '../repositories/suggestion_repository.dart';
import '../../accounts/repositories/account_repository.dart';
import '../../goals/repositories/goal_repository.dart';
import '../../auth/repositories/profile_repository.dart';
import '../../budget/repositories/budget_repository.dart';
import '../../accounts/models/account.dart';
import '../../budget/models/budget_category.dart';
import '../../goals/models/goal.dart';
import '../../goals/models/allocation.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final SuggestionRepository suggestionRepository;
  final AccountRepository accountRepository;
  final GoalRepository goalRepository;
  final ProfileRepository profileRepository;
  final BudgetRepository budgetRepository;

  DashboardBloc({
    required this.suggestionRepository,
    required this.accountRepository,
    required this.goalRepository,
    required this.profileRepository,
    required this.budgetRepository,
  }) : super(DashboardInitial()) {
    on<DashboardInitialDataRequested>(_onDashboardInitialDataRequested);
    on<GenerateSuggestionsRequested>(_onGenerateSuggestionsRequested);
    on<AcceptSuggestionRequested>(_onAcceptSuggestionRequested);
    on<DashboardResetRequested>(_onDashboardResetRequested);
  }

  Future<void> _onDashboardInitialDataRequested(
    DashboardInitialDataRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());

    try {
      final results = await Future.wait([
        accountRepository.getAccounts(),
        budgetRepository.getBudgetCategories(),
        goalRepository.getGoals(),
        goalRepository.getAllocations(),
      ]);

      emit(
        DashboardDataLoaded(
          accounts: results[0] as List<Account>,
          budgetCategories: results[1] as List<BudgetCategory>,
          goals: results[2] as List<Goal>,
          recentAllocations: results[3] as List<GoalAllocation>,
        ),
      );
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> _onGenerateSuggestionsRequested(
    GenerateSuggestionsRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());

    try {
      final accounts = await accountRepository.getAccounts();
      final goals = await goalRepository.getGoals();
      final recentAllocations = await goalRepository.getRecentAllocationSummary(
        30,
      );
      final defaultRatio = await profileRepository.getDefaultSavingsRatio();

      final result = await suggestionRepository.getSuggestions(
        excessFunds: event.excessFunds,
        accounts: accounts,
        goals: goals,
        recentAllocations: recentAllocations,
        defaultSavingsRatio: defaultRatio,
      );

      emit(DashboardSuggestionsLoaded(result, goals));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> _onAcceptSuggestionRequested(
    AcceptSuggestionRequested event,
    Emitter<DashboardState> emit,
  ) async {
    final allocation = event.allocation;

    try {
      if (allocation.type == 'goal') {
        if (event.subGoalDistribution != null &&
            event.subGoalDistribution!.isNotEmpty) {
          // If we have a distribution, create an allocation for each subgoal
          for (var entry in event.subGoalDistribution!.entries) {
            await goalRepository.insertAllocation(
              allocation.id,
              entry.value,
              accountId: allocation.accountId,
              subGoalId: entry.key,
            );
          }
        } else {
          // Simple goal allocation
          await goalRepository.insertAllocation(
            allocation.id,
            allocation.amount,
            accountId: allocation.accountId,
          );
        }
      } else if (allocation.type == 'account') {
        // Direct account balance update (e.g. for non-goal allocations)
        final accounts = await accountRepository.getAccounts();
        final account = accounts.firstWhere((a) => a.id == allocation.id);

        await accountRepository.updateAccountBalance(
          allocation.id,
          account.balance + allocation.amount,
        );
      }

      // Refresh data after allocation
      add(DashboardInitialDataRequested());
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  void _onDashboardResetRequested(
    DashboardResetRequested event,
    Emitter<DashboardState> emit,
  ) {
    emit(DashboardInitial());
  }
}
