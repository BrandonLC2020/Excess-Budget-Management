import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import '../models/profile.dart';

class AuthService {
  AuthService(this._client);
  final ApiClient _client;

  Future<UserProfile> signUp(String email, String password) async {
    final r = await _client.post<Map<String, dynamic>>(
      '/auth/signup',
      body: {'email': email, 'password': password},
    );
    await _client.tokenStore.write(
      r.data!['access'] as String,
      r.data!['refresh'] as String,
    );
    return UserProfile.fromJson(r.data!['user'] as Map<String, dynamic>);
  }

  Future<UserProfile> signIn(String email, String password) async {
    final r = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    await _client.tokenStore.write(
      r.data!['access'] as String,
      r.data!['refresh'] as String,
    );
    return UserProfile.fromJson(r.data!['user'] as Map<String, dynamic>);
  }

  Future<void> signOut() => _client.tokenStore.clear();

  Future<UserProfile?> currentUser() async {
    try {
      final r = await _client.get<Map<String, dynamic>>('/auth/me');
      return UserProfile.fromJson(r.data!);
    } on ApiAuthException {
      return null;
    }
  }
}
