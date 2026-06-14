// Uses the same queue-based HttpClientAdapter pattern as auth_interceptor_test.dart
// to avoid the last-registered-match-wins limitation of http_mock_adapter.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/auth_token_store.dart';
import 'package:frontend/features/auth/services/auth_service.dart';

class _MockTokenStore extends Mock implements AuthTokenStore {}

/// Queue-based adapter — returns scripted responses in order.
class _QueueAdapter implements HttpClientAdapter {
  final _queue = <ResponseBody>[];

  void enqueue(int status, Object? body) {
    _queue.add(
      ResponseBody.fromString(
        body != null ? jsonEncode(body) : '',
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    assert(_queue.isNotEmpty, 'No more queued responses');
    return _queue.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _QueueAdapter adapter;
  late _MockTokenStore tokenStore;
  late ApiClient apiClient;
  late AuthService authService;

  setUp(() {
    adapter = _QueueAdapter();
    tokenStore = _MockTokenStore();

    when(() => tokenStore.write(any(), any())).thenAnswer((_) async {});
    when(() => tokenStore.readAccess()).thenAnswer((_) async => null);
    when(() => tokenStore.readRefresh()).thenAnswer((_) async => null);
    when(() => tokenStore.clear()).thenAnswer((_) async {});

    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = adapter;

    apiClient = ApiClient(
      dio: dio,
      tokenStore: tokenStore,
      onUnauthenticated: () async {},
    );

    authService = AuthService(apiClient);
  });

  group('AuthService.signIn', () {
    test(
      'happy path: POSTs to /auth/login, persists tokens, returns UserProfile',
      () async {
        adapter.enqueue(200, {
          'access': 'access-abc',
          'refresh': 'refresh-xyz',
          'user': {
            'id': 'user-1',
            'email': 'alice@example.com',
            'full_name': 'Alice',
            'avatar_url': null,
            'default_savings_ratio': 0.3,
            'date_joined': '2024-01-01T00:00:00Z',
          },
        });

        final profile = await authService.signIn(
          'alice@example.com',
          'password1',
        );

        expect(profile.id, 'user-1');
        expect(profile.email, 'alice@example.com');
        expect(profile.fullName, 'Alice');
        expect(profile.defaultSavingsRatio, 0.3);

        verify(() => tokenStore.write('access-abc', 'refresh-xyz')).called(1);
      },
    );
  });

  group('AuthService.signInWithAuth0', () {
    test(
      'happy path: POSTs to /auth/auth0, persists tokens, returns UserProfile',
      () async {
        adapter.enqueue(200, {
          'access': 'access-auth0',
          'refresh': 'refresh-auth0',
          'user': {
            'id': 'user-auth0',
            'email': 'auth0@example.com',
            'full_name': 'Auth0 User',
            'avatar_url': 'https://example.com/avatar.png',
            'default_savings_ratio': 0.5,
            'date_joined': '2024-01-01T00:00:00Z',
          },
        });

        final profile = await authService.signInWithAuth0('auth0-token-123');

        expect(profile.id, 'user-auth0');
        expect(profile.email, 'auth0@example.com');
        expect(profile.fullName, 'Auth0 User');
        expect(profile.avatarUrl, 'https://example.com/avatar.png');
        expect(profile.defaultSavingsRatio, 0.5);

        verify(
          () => tokenStore.write('access-auth0', 'refresh-auth0'),
        ).called(1);
      },
    );
  });

  group('AuthService.signUp', () {
    test(
      'happy path: POSTs to /auth/signup, persists tokens, returns UserProfile',
      () async {
        adapter.enqueue(201, {
          'access': 'access-new',
          'refresh': 'refresh-new',
          'user': {
            'id': 'user-2',
            'email': 'bob@example.com',
            'full_name': '',
            'avatar_url': null,
            'default_savings_ratio': 0.5,
            'date_joined': '2024-01-01T00:00:00Z',
          },
        });

        final profile = await authService.signUp(
          'bob@example.com',
          'password2',
        );

        expect(profile.id, 'user-2');
        expect(profile.email, 'bob@example.com');
        expect(profile.defaultSavingsRatio, 0.5);

        verify(() => tokenStore.write('access-new', 'refresh-new')).called(1);
      },
    );
  });

  group('AuthService.currentUser', () {
    test('returns UserProfile when /auth/me succeeds', () async {
      when(() => tokenStore.readAccess()).thenAnswer((_) async => 'access-abc');
      adapter.enqueue(200, {
        'id': 'user-1',
        'email': 'alice@example.com',
        'full_name': 'Alice',
        'avatar_url': null,
        'default_savings_ratio': 0.3,
        'date_joined': '2024-01-01T00:00:00Z',
      });

      final profile = await authService.currentUser();

      expect(profile, isNotNull);
      expect(profile!.id, 'user-1');
    });

    test('returns null when /auth/me returns 401', () async {
      // Two 401s because the AuthInterceptor will also attempt a refresh
      adapter.enqueue(401, {
        'error': {'code': 'auth_error', 'message': 'no token'},
      });
      adapter.enqueue(401, {
        'error': {'code': 'auth_error', 'message': 'no refresh'},
      });

      final profile = await authService.currentUser();

      expect(profile, isNull);
    });
  });

  group('AuthService.signOut', () {
    test('clears token store', () async {
      await authService.signOut();
      verify(() => tokenStore.clear()).called(1);
    });
  });
}
