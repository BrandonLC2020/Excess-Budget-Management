import 'package:flutter_bloc/flutter_bloc.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';
import '../repositories/suggestion_repository.dart';
import '../../accounts/repositories/account_repository.dart';
import '../../goals/repositories/goal_repository.dart';
import '../../auth/repositories/profile_repository.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final SuggestionRepository suggestionRepository;
  final AccountRepository accountRepository;
  final GoalRepository goalRepository;
  final ProfileRepository profileRepository;

  DashboardBloc({
    required this.suggestionRepository,
    required this.accountRepository,
    required this.goalRepository,
    required this.profileRepository,
  }) : super(DashboardInitial()) {
    on<GenerateSuggestionsRequested>(_onGenerateSuggestionsRequested);
    on<AcceptSuggestionRequested>(_onAcceptSuggestionRequested);
    on<DashboardResetRequested>(_onDashboardResetRequested);
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
        final goals = await goalRepository.getGoals();
        final goal = goals.firstWhere((g) => g.id == allocation.id);

        if (event.subGoalDistribution != null &&
            event.subGoalDistribution!.isNotEmpty) {
          // Update each subgoal
          for (var entry in event.subGoalDistribution!.entries) {
            final subGoal = goal.subGoals.firstWhere(
              (sg) => sg.id == entry.key,
            );
            await goalRepository.updateSubGoalAmount(
              subGoal.id,
              subGoal.currentAmount + entry.value,
            );
          }
          // The parent goal's current_amount is automatically updated by the DB trigger
        } else {
          // Fallback if no distribution was provided (e.g., flat goal)
          await goalRepository.updateGoalCurrentAmount(
            allocation.id,
            goal.currentAmount + allocation.amount,
          );
        }

        await goalRepository.insertAllocation(allocation.id, allocation.amount);
      } else {
        final accounts = await accountRepository.getAccounts();
        final account = accounts.firstWhere((a) => a.id == allocation.id);

        await accountRepository.updateAccountBalance(
          allocation.id,
          account.balance + allocation.amount,
        );
      }

      // Optionally re-fetch suggestions or refresh state
      // For now, let's trigger a refresh of the suggestions to show updated progress
      // (This requires another GenerateSuggestionsRequested dispatch or similar)
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
