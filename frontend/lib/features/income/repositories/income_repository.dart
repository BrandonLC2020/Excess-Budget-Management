import 'package:frontend/core/api/api_client.dart';
import '../models/income.dart';
import '../models/overtime_settings.dart';
import '../models/overtime_projection.dart';

class IncomeRepository {
  IncomeRepository({required this.client});
  final ApiClient client;

  Future<List<Income>> getIncome() async {
    final r = await client.get<List<dynamic>>('/income/extra');
    return r.data!
        .map((e) => Income.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteIncome(String id) =>
      client.delete<void>('/income/extra/$id');

  /// Inserts each extra income entry individually via POST /income/extra.
  /// Strips `user_id` keys (server infers from auth).
  /// Note: N round-trips — acceptable for dev; a future bulk endpoint can batch.
  Future<void> bulkInsertExtraIncome(
    List<Map<String, dynamic>> incomeEntries,
  ) async {
    for (final entry in incomeEntries) {
      final body = Map<String, dynamic>.from(entry)..remove('user_id');
      await client.post<Map<String, dynamic>>('/income/extra', body: body);
    }
  }

  // ── Overtime Settings & Calculations ──────────────────────────────────────────

  Future<OvertimeSettings> getOvertimeSettings() async {
    final r = await client.get<Map<String, dynamic>>(
      '/income/overtime/settings',
    );
    return OvertimeSettings.fromJson(r.data!);
  }

  Future<OvertimeSettings> updateOvertimeSettings(
    OvertimeSettings settings,
  ) async {
    final r = await client.patch<Map<String, dynamic>>(
      '/income/overtime/settings',
      body: settings.toJson(),
    );
    return OvertimeSettings.fromJson(r.data!);
  }

  Future<OvertimeProjection> getOvertimeProjection({
    required double overtimeHoursPerWeek,
    String? goalId,
    String? subgoalId,
    double standardContribution = 0.0,
  }) async {
    final body = {
      'overtime_hours_per_week': overtimeHoursPerWeek,
      'standard_contribution': standardContribution,
      'goal_id': ?goalId,
      'subgoal_id': ?subgoalId,
    };
    final r = await client.post<Map<String, dynamic>>(
      '/income/overtime/projections',
      body: body,
    );
    return OvertimeProjection.fromJson(r.data!);
  }
}
