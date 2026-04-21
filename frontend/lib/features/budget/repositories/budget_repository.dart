import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/budget_category.dart';

class BudgetRepository {
  final SupabaseClient supabase;

  BudgetRepository({required this.supabase});

  Future<List<BudgetCategory>> getBudgetCategories() async {
    final response = await supabase
        .from('budget_categories')
        .select()
        .order('created_at', ascending: true);
    return (response as List).map((e) => BudgetCategory.fromJson(e)).toList();
  }

  Future<BudgetCategory> addBudgetCategory(
    String name,
    double limitAmount, {
    int? iconCode,
    String? colorHex,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final response = await supabase
        .from('budget_categories')
        .insert({
          'user_id': userId,
          'name': name,
          'limit_amount': limitAmount,
          'icon_code': iconCode,
          'color_hex': colorHex,
        })
        .select()
        .single();

    return BudgetCategory.fromJson(response);
  }

  Future<BudgetCategory> updateBudgetCategory(
    String id,
    String name,
    double limitAmount, {
    int? iconCode,
    String? colorHex,
  }) async {
    final response = await supabase
        .from('budget_categories')
        .update({
          'name': name,
          'limit_amount': limitAmount,
          'icon_code': iconCode,
          'color_hex': colorHex,
        })
        .eq('id', id)
        .select()
        .single();

    return BudgetCategory.fromJson(response);
  }

  Future<void> deleteBudgetCategory(String id) async {
    await supabase.from('budget_categories').delete().eq('id', id);
  }

  Future<void> bulkInsertExpenses(List<Map<String, dynamic>> expenses) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final rowsToInsert = expenses
        .map((e) => {...e, 'user_id': userId})
        .toList();

    await supabase.from('expenses').insert(rowsToInsert);
  }
}
