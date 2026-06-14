import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/features/auth/bloc/auth_state.dart';
import 'package:frontend/features/auth/models/profile.dart';
import 'package:frontend/features/auth/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;
  late UserProfile mockUser;

  setUp(() {
    mockAuthService = MockAuthService();
    mockUser = const UserProfile(
      id: 'user-auth0',
      email: 'auth0@example.com',
      fullName: 'Auth0 User',
      avatarUrl: 'https://example.com/avatar.png',
      defaultSavingsRatio: 0.5,
    );
  });

  group('AuthBloc - AuthAuth0LoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when Auth0 login succeeds',
      build: () {
        when(
          () => mockAuthService.signInWithAuth0(any()),
        ).thenAnswer((_) async => mockUser);
        return AuthBloc(authService: mockAuthService);
      },
      act: (bloc) => bloc.add(const AuthAuth0LoginRequested('token-123')),
      expect: () => [AuthLoading(), AuthAuthenticated(mockUser)],
      verify: (_) {
        verify(() => mockAuthService.signInWithAuth0('token-123')).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when Auth0 login fails',
      build: () {
        when(
          () => mockAuthService.signInWithAuth0(any()),
        ).thenThrow(const ApiAuthException('Auth0 authentication failed'));
        return AuthBloc(authService: mockAuthService);
      },
      act: (bloc) => bloc.add(const AuthAuth0LoginRequested('token-123')),
      expect: () => [
        AuthLoading(),
        const AuthError('Auth0 authentication failed'),
      ],
    );
  });
}
