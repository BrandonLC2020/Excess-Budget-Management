import 'dart:async';
import 'package:dio/dio.dart';
import 'auth_token_store.dart';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.dio,
    required this.tokenStore,
    required this.onUnauthenticated,
  }) : _refreshDio = Dio(
          BaseOptions(
            baseUrl: dio.options.baseUrl,
            connectTimeout: dio.options.connectTimeout,
            receiveTimeout: dio.options.receiveTimeout,
            headers: Map.of(dio.options.headers),
            contentType: dio.options.contentType,
            responseType: dio.options.responseType,
          ),
        ) {
    // Share the same adapter so tests can mock the refresh endpoint too.
    _refreshDio.httpClientAdapter = dio.httpClientAdapter;
  }

  final Dio dio;
  final Dio _refreshDio;
  final AuthTokenStore tokenStore;
  final FutureOr<void> Function() onUnauthenticated;
  Future<void>? _inflightRefresh;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.contains('/auth/')) return handler.next(options);
    final token = await tokenStore.readAccess();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isAuth = err.requestOptions.path.contains('/auth/');
    if (err.response?.statusCode != 401 || isAuth) return handler.next(err);
    try {
      await (_inflightRefresh ??= _refresh());
    } catch (_) {
      await tokenStore.clear();
      await onUnauthenticated();
      return handler.next(err);
    } finally {
      _inflightRefresh = null;
    }
    final retried = await dio.fetch(err.requestOptions);
    handler.resolve(retried);
  }

  Future<void> _refresh() async {
    final refresh = await tokenStore.readRefresh();
    if (refresh == null) throw StateError('no refresh token');
    // Use a separate Dio instance (no interceptors) to avoid deadlocking the
    // QueuedInterceptor error queue when the refresh call itself fails.
    final r = await _refreshDio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh': refresh},
    );
    await tokenStore.write(
      r.data!['access'] as String,
      r.data!['refresh'] as String,
    );
  }
}
