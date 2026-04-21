import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class ProfileRepository {
  final SupabaseClient supabase;

  ProfileRepository({required this.supabase});

  Future<UserProfile> getProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final response = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return UserProfile.fromJson(response);
  }

  Future<void> updateProfile(UserProfile profile) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await supabase.from('profiles').update(profile.toJson()).eq('id', userId);
  }

  Future<String> uploadAvatar(XFile file) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final fileExt = file.path.split('.').last;
    final fileName = '$userId/avatar.$fileExt';
    final filePath = fileName;

    await supabase.storage
        .from('avatars')
        .upload(
          filePath,
          File(file.path),
          fileOptions: const FileOptions(upsert: true),
        );

    final String publicUrl = supabase.storage
        .from('avatars')
        .getPublicUrl(filePath);
    return publicUrl;
  }

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
