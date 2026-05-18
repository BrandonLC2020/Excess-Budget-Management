import 'package:frontend/core/api/api_client.dart';
import '../models/income.dart';

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
}
