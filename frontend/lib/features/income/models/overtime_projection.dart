class OvertimeProjection {
  final double netHourlyRate;
  final double weeklyOvertimeNetIncome;
  final double monthlyOvertimeNetIncome;
  final double? totalHoursNeeded;
  final double? monthsToCompleteStandard;
  final double? monthsToCompleteWithOvertime;
  final double? monthsSaved;

  OvertimeProjection({
    required this.netHourlyRate,
    required this.weeklyOvertimeNetIncome,
    required this.monthlyOvertimeNetIncome,
    this.totalHoursNeeded,
    this.monthsToCompleteStandard,
    this.monthsToCompleteWithOvertime,
    this.monthsSaved,
  });

  factory OvertimeProjection.fromJson(Map<String, dynamic> json) {
    return OvertimeProjection(
      netHourlyRate: double.tryParse(json['net_hourly_rate'].toString()) ?? 0.0,
      weeklyOvertimeNetIncome: double.tryParse(json['weekly_overtime_net_income'].toString()) ?? 0.0,
      monthlyOvertimeNetIncome: double.tryParse(json['monthly_overtime_net_income'].toString()) ?? 0.0,
      totalHoursNeeded: json['total_hours_needed'] != null ? double.tryParse(json['total_hours_needed'].toString()) : null,
      monthsToCompleteStandard: json['months_to_complete_standard'] != null ? double.tryParse(json['months_to_complete_standard'].toString()) : null,
      monthsToCompleteWithOvertime: json['months_to_complete_with_overtime'] != null ? double.tryParse(json['months_to_complete_with_overtime'].toString()) : null,
      monthsSaved: json['months_saved'] != null ? double.tryParse(json['months_saved'].toString()) : null,
    );
  }
}
