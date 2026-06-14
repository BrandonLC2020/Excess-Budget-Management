import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/utils/optional.dart';
import '../repositories/income_repository.dart';
import '../../goals/repositories/goal_repository.dart';
import '../../goals/models/goal.dart';
import '../models/overtime_settings.dart';
import '../models/overtime_projection.dart';

part 'overtime_event.dart';
part 'overtime_state.dart';

class OvertimeBloc extends Bloc<OvertimeEvent, OvertimeState> {
  final IncomeRepository incomeRepository;
  final GoalRepository goalRepository;

  OvertimeBloc({required this.incomeRepository, required this.goalRepository})
    : super(OvertimeState()) {
    on<FetchOvertimeData>(_onFetchOvertimeData);
    on<UpdateOvertimeSettingsField>(_onUpdateOvertimeSettingsField);
    on<UpdateOvertimeHours>(_onUpdateOvertimeHours);
    on<UpdateStandardContribution>(_onUpdateStandardContribution);
    on<SelectGoalOrSubgoal>(_onSelectGoalOrSubgoal);
    on<SaveOvertimeSettings>(_onSaveOvertimeSettings);
    on<_CalculateProjections>(_onCalculateProjections);
  }

  Future<void> _onFetchOvertimeData(
    FetchOvertimeData event,
    Emitter<OvertimeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: const Wrapped(null)));
    try {
      final settings = await incomeRepository.getOvertimeSettings();
      final goals = await goalRepository.getGoals();

      // Find first uncompleted goal (if any) to pre-select
      String? defaultGoalId;
      if (goals.isNotEmpty) {
        final uncompleted = goals.where((g) => !g.isCompleted).toList();
        if (uncompleted.isNotEmpty) {
          defaultGoalId = uncompleted.first.id;
        } else {
          defaultGoalId = goals.first.id;
        }
      }

      emit(
        state.copyWith(
          isLoading: false,
          settings: settings,
          goals: goals,
          selectedGoalId: Wrapped(defaultGoalId),
        ),
      );

      add(_CalculateProjections());
    } catch (e) {
      emit(
        state.copyWith(isLoading: false, errorMessage: Wrapped(e.toString())),
      );
    }
  }

  void _onUpdateOvertimeSettingsField(
    UpdateOvertimeSettingsField event,
    Emitter<OvertimeState> emit,
  ) {
    if (state.settings == null) return;

    final newSettings = state.settings!.copyWith(
      hourlyBaseRate: event.hourlyBaseRate,
      overtimeMultiplier: event.overtimeMultiplier,
      estimatedTaxRate: event.estimatedTaxRate,
    );

    emit(state.copyWith(settings: newSettings));
    add(_CalculateProjections());
  }

  void _onUpdateOvertimeHours(
    UpdateOvertimeHours event,
    Emitter<OvertimeState> emit,
  ) {
    emit(state.copyWith(overtimeHoursPerWeek: event.hours));
    add(_CalculateProjections());
  }

  void _onUpdateStandardContribution(
    UpdateStandardContribution event,
    Emitter<OvertimeState> emit,
  ) {
    emit(state.copyWith(standardContribution: event.contribution));
    add(_CalculateProjections());
  }

  void _onSelectGoalOrSubgoal(
    SelectGoalOrSubgoal event,
    Emitter<OvertimeState> emit,
  ) {
    emit(
      state.copyWith(
        selectedGoalId: Wrapped(event.goalId),
        selectedSubgoalId: Wrapped(event.subgoalId),
      ),
    );
    add(_CalculateProjections());
  }

  Future<void> _onSaveOvertimeSettings(
    SaveOvertimeSettings event,
    Emitter<OvertimeState> emit,
  ) async {
    if (state.settings == null) return;

    emit(state.copyWith(isSaving: true, errorMessage: const Wrapped(null)));
    try {
      final savedSettings = await incomeRepository.updateOvertimeSettings(
        state.settings!,
      );
      emit(state.copyWith(isSaving: false, settings: savedSettings));
      add(_CalculateProjections());
    } catch (e) {
      emit(
        state.copyWith(isSaving: false, errorMessage: Wrapped(e.toString())),
      );
    }
  }

  Future<void> _onCalculateProjections(
    _CalculateProjections event,
    Emitter<OvertimeState> emit,
  ) async {
    if (state.settings == null) return;

    emit(state.copyWith(isCalculating: true));
    try {
      final projection = await incomeRepository.getOvertimeProjection(
        overtimeHoursPerWeek: state.overtimeHoursPerWeek,
        standardContribution: state.standardContribution,
        goalId: state.selectedGoalId,
        subgoalId: state.selectedSubgoalId,
      );
      emit(
        state.copyWith(isCalculating: false, projection: Wrapped(projection)),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isCalculating: false,
          errorMessage: Wrapped(e.toString()),
        ),
      );
    }
  }
}

class _CalculateProjections extends OvertimeEvent {}
