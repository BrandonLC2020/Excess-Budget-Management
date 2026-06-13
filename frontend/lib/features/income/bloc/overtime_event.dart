part of 'overtime_bloc.dart';

abstract class OvertimeEvent {}

class FetchOvertimeData extends OvertimeEvent {}

class UpdateOvertimeSettingsField extends OvertimeEvent {
  final double? hourlyBaseRate;
  final double? overtimeMultiplier;
  final double? estimatedTaxRate;

  UpdateOvertimeSettingsField({
    this.hourlyBaseRate,
    this.overtimeMultiplier,
    this.estimatedTaxRate,
  });
}

class UpdateOvertimeHours extends OvertimeEvent {
  final double hours;

  UpdateOvertimeHours(this.hours);
}

class UpdateStandardContribution extends OvertimeEvent {
  final double contribution;

  UpdateStandardContribution(this.contribution);
}

class SelectGoalOrSubgoal extends OvertimeEvent {
  final String? goalId;
  final String? subgoalId;

  SelectGoalOrSubgoal({this.goalId, this.subgoalId});
}

class SaveOvertimeSettings extends OvertimeEvent {}
