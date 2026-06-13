part of 'overtime_bloc.dart';

class OvertimeState {
  final bool isLoading;
  final bool isSaving;
  final bool isCalculating;
  final String? errorMessage;
  final OvertimeSettings? settings;
  final List<Goal> goals;
  final String? selectedGoalId;
  final String? selectedSubgoalId;
  final double overtimeHoursPerWeek;
  final double standardContribution;
  final OvertimeProjection? projection;

  OvertimeState({
    this.isLoading = false,
    this.isSaving = false,
    this.isCalculating = false,
    this.errorMessage,
    this.settings,
    this.goals = const [],
    this.selectedGoalId,
    this.selectedSubgoalId,
    this.overtimeHoursPerWeek = 0.0,
    this.standardContribution = 0.0,
    this.projection,
  });

  OvertimeState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isCalculating,
    Wrapped<String?>? errorMessage,
    OvertimeSettings? settings,
    List<Goal>? goals,
    Wrapped<String?>? selectedGoalId,
    Wrapped<String?>? selectedSubgoalId,
    double? overtimeHoursPerWeek,
    double? standardContribution,
    Wrapped<OvertimeProjection?>? projection,
  }) {
    return OvertimeState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isCalculating: isCalculating ?? this.isCalculating,
      errorMessage: errorMessage != null ? errorMessage.value : this.errorMessage,
      settings: settings ?? this.settings,
      goals: goals ?? this.goals,
      selectedGoalId: selectedGoalId != null ? selectedGoalId.value : this.selectedGoalId,
      selectedSubgoalId: selectedSubgoalId != null ? selectedSubgoalId.value : this.selectedSubgoalId,
      overtimeHoursPerWeek: overtimeHoursPerWeek ?? this.overtimeHoursPerWeek,
      standardContribution: standardContribution ?? this.standardContribution,
      projection: projection != null ? projection.value : this.projection,
    );
  }
}
