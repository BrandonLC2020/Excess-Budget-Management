import 'package:frontend/core/api/api_client.dart';
import '../models/allocation.dart';

class SuggestionRepository {
  SuggestionRepository({required this.client});
  final ApiClient client;

  /// Generates AI suggestions by sending excess_funds to the Django backend.
  /// The server gathers all context (accounts, goals, allocations, profile)
  /// from the authenticated user — no client-side context needed.
  Future<SuggestionResult> getSuggestions({required double excessFunds}) async {
    final r = await client.post<Map<String, dynamic>>(
      '/suggestions/generate',
      body: {'excess_funds': excessFunds.toStringAsFixed(2)},
    );
    return SuggestionResult.fromJson(r.data!);
  }
}
