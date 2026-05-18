import 'package:image_picker/image_picker.dart';
import 'package:frontend/core/api/api_client.dart';
import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository({required this.client});
  final ApiClient client;

  Future<UserProfile> getProfile() async {
    final r = await client.get<Map<String, dynamic>>('/auth/me');
    return UserProfile.fromJson(r.data!);
  }

  Future<void> updateProfile(UserProfile profile) async {
    await client.patch<Map<String, dynamic>>('/auth/me', body: {
      'full_name': profile.fullName,
      'avatar_url': profile.avatarUrl,
      'default_savings_ratio': profile.defaultSavingsRatio,
    });
  }

  Future<String> uploadAvatar(XFile file) async {
    // TODO: implement after Django backend gains a storage layer.
    // Supabase Storage avatars bucket is not yet ported.
    throw UnimplementedError(
      'Avatar upload is pending the storage-backend migration.',
    );
  }

  Future<double> getDefaultSavingsRatio() async {
    final p = await getProfile();
    return p.defaultSavingsRatio;
  }

  Future<void> updateDefaultSavingsRatio(double ratio) async {
    await client.patch<Map<String, dynamic>>('/auth/me',
        body: {'default_savings_ratio': ratio});
  }
}
