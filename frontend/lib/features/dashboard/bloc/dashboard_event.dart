import '../models/allocation.dart';

abstract class DashboardEvent {}

class GenerateSuggestionsRequested extends DashboardEvent {
  final double excessFunds;

  GenerateSuggestionsRequested(this.excessFunds);
}

class AcceptSuggestionRequested extends DashboardEvent {
  final Allocation allocation;
  final Map<String, double>? subGoalDistribution;

  AcceptSuggestionRequested(this.allocation, {this.subGoalDistribution});
}

class DashboardResetRequested extends DashboardEvent {}
