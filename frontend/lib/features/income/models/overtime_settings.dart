class OvertimeSettings {
  final double hourlyBaseRate;
  final double overtimeMultiplier;
  final double estimatedTaxRate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OvertimeSettings({
    required this.hourlyBaseRate,
    required this.overtimeMultiplier,
    required this.estimatedTaxRate,
    this.createdAt,
    this.updatedAt,
  });

  factory OvertimeSettings.fromJson(Map<String, dynamic> json) {
    return OvertimeSettings(
      hourlyBaseRate:
          double.tryParse(json['hourly_base_rate'].toString()) ?? 0.0,
      overtimeMultiplier:
          double.tryParse(json['overtime_multiplier'].toString()) ?? 1.5,
      estimatedTaxRate:
          double.tryParse(json['estimated_tax_rate'].toString()) ?? 0.25,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hourly_base_rate': hourlyBaseRate,
      'overtime_multiplier': overtimeMultiplier,
      'estimated_tax_rate': estimatedTaxRate,
    };
  }

  OvertimeSettings copyWith({
    double? hourlyBaseRate,
    double? overtimeMultiplier,
    double? estimatedTaxRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OvertimeSettings(
      hourlyBaseRate: hourlyBaseRate ?? this.hourlyBaseRate,
      overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
      estimatedTaxRate: estimatedTaxRate ?? this.estimatedTaxRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
