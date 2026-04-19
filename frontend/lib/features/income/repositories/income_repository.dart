import 'package:supabase_flutter/supabase_flutter.dart';

class IncomeRepository {
  final SupabaseClient supabase;

  IncomeRepository({required this.supabase});

  Future<void> bulkInsertExtraIncome(List<Map<String, dynamic>> incomeEntries) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final rowsToInsert = incomeEntries.map((e) => {...e, 'user_id': userId}).toList();
    
    await supabase.from('extra_income').insert(rowsToInsert);
  }
}
