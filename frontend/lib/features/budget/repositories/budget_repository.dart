import 'dart:async';
import 'package:frontend/core/api/api_client.dart';
import '../../income/models/income.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';

class BudgetRepository {
  BudgetRepository({required this.client});
  final ApiClient client;

  Future<List<BudgetCategory>> getBudgetCategories() async {
    final r = await client.get<List<dynamic>>('/budget/categories');
    return r.data!
        .map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Polled replacement for Supabase realtime stream.
  /// Emits the current list immediately, then every 30 seconds.
  Stream<List<BudgetCategory>> getBudgetCategoriesStream() async* {
    yield await getBudgetCategories();
    yield* Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => getBudgetCategories());
  }

  Future<List<Expense>> getExpenses() async {
    final r = await client.get<List<dynamic>>('/expenses');
    return r.data!
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteExpense(String id) =>
      client.delete<void>('/expenses/$id');

  Future<BudgetCategory> addBudgetCategory(
    String name,
    double limitAmount, {
    int? iconCode,
    String? colorHex,
    BudgetCategoryType type = BudgetCategoryType.expense,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'limit_amount': limitAmount.toStringAsFixed(2),
      'category_type': type.name,
    };
    if (iconCode != null) body['icon_code'] = iconCode;
    if (colorHex != null) body['color_hex'] = colorHex;

    final r = await client.post<Map<String, dynamic>>(
      '/budget/categories',
      body: body,
    );
    return BudgetCategory.fromJson(r.data!);
  }

  Future<BudgetCategory> updateBudgetCategory(
    String id,
    String name,
    double limitAmount, {
    int? iconCode,
    String? colorHex,
    BudgetCategoryType? type,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'limit_amount': limitAmount.toStringAsFixed(2),
    };
    if (iconCode != null) body['icon_code'] = iconCode;
    if (colorHex != null) body['color_hex'] = colorHex;
    if (type != null) body['category_type'] = type.name;

    final r = await client.patch<Map<String, dynamic>>(
      '/budget/categories/$id',
      body: body,
    );
    return BudgetCategory.fromJson(r.data!);
  }

  Future<void> deleteBudgetCategory(String id) =>
      client.delete<void>('/budget/categories/$id');

  /// Inserts each expense individually via POST /expenses.
  /// Strips `user_id` keys (server infers from auth).
  /// Note: N round-trips — acceptable for dev; a future bulk endpoint can batch.
  Future<void> bulkInsertExpenses(List<Map<String, dynamic>> expenses) async {
    for (final expense in expenses) {
      final body = Map<String, dynamic>.from(expense)..remove('user_id');
      await client.post<Map<String, dynamic>>('/expenses', body: body);
    }
  }

  Future<List<Expense>> getCategoryExpenses(String categoryId) async {
    final r = await client.get<List<dynamic>>(
      '/expenses',
      query: {'budget_category_id': categoryId},
    );
    return r.data!
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Income>> getCategoryIncome(String categoryId) async {
    final r = await client.get<List<dynamic>>(
      '/income/extra',
      query: {'budget_category_id': categoryId},
    );
    return r.data!
        .map((e) => Income.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
