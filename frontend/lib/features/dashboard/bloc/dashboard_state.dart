import '../models/allocation.dart';
import '../../goals/models/goal.dart';

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardSuggestionsLoaded extends DashboardState {
  final SuggestionResult result;
  final List<Goal> goals;

  DashboardSuggestionsLoaded(this.result, this.goals);
}

class DashboardError extends DashboardState {
  final String message;

  DashboardError(this.message);
}
