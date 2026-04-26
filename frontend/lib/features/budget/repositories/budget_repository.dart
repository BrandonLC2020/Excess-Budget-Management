import 'package:supabase_flutter/supabase_flutter.dart';
import '../../income/models/income.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';

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

  Stream<List<BudgetCategory>> getBudgetCategoriesStream() {
    return supabase
        .from('budget_categories')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => BudgetCategory.fromJson(e)).toList());
  }

  Future<List<Expense>> getExpenses() async {
    final response = await supabase
        .from('expenses')
        .select()
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Expense.fromJson(e)).toList();
  }

  Future<void> deleteExpense(String id) async {
    await supabase.from('expenses').delete().eq('id', id);
  }

  Future<BudgetCategory> addBudgetCategory(
    String name,
    double limitAmount, {
    int? iconCode,
    String? colorHex,
    BudgetCategoryType type = BudgetCategoryType.expense,
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
          'category_type': type.name,
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
    BudgetCategoryType? type,
  }) async {
    final updates = {
      'name': name,
      'limit_amount': limitAmount,
      'icon_code': iconCode,
      'color_hex': colorHex,
    };

    if (type != null) {
      updates['category_type'] = type.name;
    }

    final response = await supabase
        .from('budget_categories')
        .update(updates)
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

  Future<List<Expense>> getCategoryExpenses(String categoryId) async {
    final response = await supabase
        .from('expenses')
        .select()
        .eq('budget_category_id', categoryId)
        .order('date', ascending: false);
    return (response as List).map((e) => Expense.fromJson(e)).toList();
  }

  Future<List<Income>> getCategoryIncome(String categoryId) async {
    final response = await supabase
        .from('extra_income')
        .select()
        .eq('budget_category_id', categoryId)
        .order('date_received', ascending: false);
    return (response as List).map((e) => Income.fromJson(e)).toList();
  }
}
