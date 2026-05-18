import 'dart:async';
import 'package:frontend/core/api/api_client.dart';
import '../../budget/models/expense.dart';
import '../../income/models/income.dart';
import '../models/account.dart';

class AccountRepository {
  AccountRepository({required this.client});
  final ApiClient client;

  Future<List<Account>> getAccounts() async {
    final r = await client.get<List<dynamic>>('/accounts');
    return r.data!.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Polled replacement for the old Supabase realtime stream.
  /// Emits the current account list immediately, then every 30 seconds.
  Stream<List<Account>> getAccountsStream() async* {
    yield await getAccounts();
    yield* Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => getAccounts());
  }

  Future<Account> addAccount(String name, double balance) async {
    final r = await client.post<Map<String, dynamic>>(
      '/accounts',
      body: {'name': name, 'balance': balance.toStringAsFixed(2)},
    );
    return Account.fromJson(r.data!);
  }

  Future<Account> updateAccount(String id, String name, double balance) async {
    final r = await client.patch<Map<String, dynamic>>(
      '/accounts/$id',
      body: {'name': name, 'balance': balance.toStringAsFixed(2)},
    );
    return Account.fromJson(r.data!);
  }

  Future<Account> updateAccountBalance(String id, double balance) async {
    final r = await client.patch<Map<String, dynamic>>(
      '/accounts/$id',
      body: {'balance': balance.toStringAsFixed(2)},
    );
    return Account.fromJson(r.data!);
  }

  Future<void> deleteAccount(String id) =>
      client.delete<void>('/accounts/$id');

  Future<List<Expense>> getAccountExpenses(String accountId) async {
    final r = await client.get<List<dynamic>>(
      '/expenses',
      query: {'account_id': accountId},
    );
    return r.data!.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Income>> getAccountIncome(String accountId) async {
    final r = await client.get<List<dynamic>>(
      '/income/extra',
      query: {'account_id': accountId},
    );
    return r.data!.map((e) => Income.fromJson(e as Map<String, dynamic>)).toList();
  }
}
