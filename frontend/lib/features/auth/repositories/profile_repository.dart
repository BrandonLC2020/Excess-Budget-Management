import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final SupabaseClient supabase;

  ProfileRepository({required this.supabase});

  Future<double> getDefaultSavingsRatio() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final response = await supabase
        .from('profiles')
        .select('default_savings_ratio')
        .eq('id', userId)
        .single();

    return (response['default_savings_ratio'] as num).toDouble();
  }

  Future<void> updateDefaultSavingsRatio(double ratio) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await supabase
        .from('profiles')
        .update({'default_savings_ratio': ratio})
        .eq('id', userId);
  }
}
