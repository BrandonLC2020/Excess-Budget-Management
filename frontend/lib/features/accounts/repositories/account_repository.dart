import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';

class AccountRepository {
  final SupabaseClient supabase;

  AccountRepository({required this.supabase});

  Future<List<Account>> getAccounts() async {
    final response = await supabase
        .from('accounts')
        .select()
        .order('created_at', ascending: true);
    return (response as List).map((e) => Account.fromJson(e)).toList();
  }

  Future<Account> addAccount(String name, double balance) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final response = await supabase
        .from('accounts')
        .insert({'user_id': userId, 'name': name, 'balance': balance})
        .select()
        .single();

    return Account.fromJson(response);
  }

  Future<Account> updateAccount(String id, String name, double balance) async {
    final response = await supabase
        .from('accounts')
        .update({'name': name, 'balance': balance})
        .eq('id', id)
        .select()
        .single();

    return Account.fromJson(response);
  }

  Future<Account> updateAccountBalance(String id, double balance) async {
    final response = await supabase
        .from('accounts')
        .update({'balance': balance})
        .eq('id', id)
        .select()
        .single();

    return Account.fromJson(response);
  }

  Future<void> deleteAccount(String id) async {
    await supabase.from('accounts').delete().eq('id', id);
  }
}
