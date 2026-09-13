// ─────────────────────────────────────────────────────────────────────────────
// API CLIENT
//
// One HTTP client for the whole app.
//
// Replaces per-screen `package:http` calls with inline `Uri.parse('$apiScheme://$apiHost/...')`
// in twelve places. Centralising it is what makes three things possible at all:
//
//   1. Attaching the auth token to every request without every screen remembering to.
//   2. Refreshing a expired token transparently and replaying the request, so a user
//      is never bounced to the login screen mid-booking.
//   3. Turning every failure into a typed ApiException with a message safe to show,
//      instead of `catch (_) {}` or a raw SocketException in a SnackBar.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Signals that the session ended and the user must sign in again.
typedef OnSessionExpired = void Function();

/// Exchanges a refresh token for a new session. Injected to avoid a dependency
/// cycle between the client and the auth repository that uses it.
typedef RefreshSession = Future<AuthSession?> Function(String refreshToken);

class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    Dio? dio,
    this.onSessionExpired,
  })  : _tokens = tokenStorage,
        _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      // Handled below rather than thrown, so error bodies can be parsed.
      validateStatus: (status) => status != null && status < 500,
    );

    _dio.interceptors.add(_authInterceptor());
    if (kDebugMode) _dio.interceptors.add(_logInterceptor());
  }

  final Dio _dio;
  final TokenStorage _tokens;
  final OnSessionExpired? onSessionExpired;

  /// Set by the auth repository once it exists.
  RefreshSession? refreshSession;

  /// Ensures concurrent 401s trigger exactly one refresh. Without this, six
  /// parallel requests on a screen load would each fire their own refresh, and
  /// token rotation would make five of them fail and revoke the session family.
  Future<AuthSession?>? _inFlightRefresh;

  Dio get raw => _dio;

  /* ── requests ──────────────────────────────────────────────────────────── */

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    T Function(dynamic data)? parse,
  }) async {
    return _send<T>(
      () => _dio.get<dynamic>(path, queryParameters: _clean(query), cancelToken: cancelToken),
      parse,
    );
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    T Function(dynamic data)? parse,
  }) async {
    return _send<T>(
      () => _dio.post<dynamic>(
        path,
        data: body,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
      ),
      parse,
    );
  }

  Future<T> patch<T>(
    String path, {
    Object? body,
    CancelToken? cancelToken,
    T Function(dynamic data)? parse,
  }) async {
    return _send<T>(
      () => _dio.patch<dynamic>(path, data: body, cancelToken: cancelToken),
      parse,
    );
  }

  Future<T> delete<T>(
    String path, {
    Object? body,
    CancelToken? cancelToken,
    T Function(dynamic data)? parse,
  }) async {
    return _send<T>(
      () => _dio.delete<dynamic>(path, data: body, cancelToken: cancelToken),
      parse,
    );
  }

  /// Runs a request, unwraps the `{ data: ... }` envelope, and converts every
  /// failure into an ApiException.
  Future<T> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data)? parse,
  ) async {
    try {
      final response = await request();
      final status = response.statusCode ?? 0;

      if (status >= 400) {
        throw ApiException.fromDio(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        );
      }

      final payload = _unwrap(response.data);
      if (parse != null) return parse(payload);
      return payload as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.unknown(e);
    }
  }

  /// Every v1 response is `{ "data": ... }`; legacy routes return bare bodies.
  dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((k, v) {
      if (v != null) cleaned[k] = v;
    });
    return cleaned.isEmpty ? null : cleaned;
  }

  /* ── interceptors ──────────────────────────────────────────────────────── */

  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Auth endpoints must not carry a stale token.
        final isAuthCall = options.path.startsWith('/auth/');

        if (!isAuthCall) {
          // Refresh proactively when the token is about to expire, which avoids a
          // guaranteed 401 round trip on every screen after 15 minutes.
          if (!_tokens.hasValidAccessToken && refreshSession != null) {
            await _refreshOnce();
          }
          final token = _tokens.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }

        options.headers['Accept'] = 'application/json';
        return handler.next(options);
      },

      onResponse: (response, handler) async {
        // 401 on a non-auth call: refresh once, then replay the original request.
        final status = response.statusCode ?? 0;
        final isAuthCall = response.requestOptions.path.startsWith('/auth/');
        final alreadyRetried = response.requestOptions.extra['_retried'] == true;

        if (status == 401 && !isAuthCall && !alreadyRetried && refreshSession != null) {
          final session = await _refreshOnce();

          if (session != null) {
            try {
              final retried = await _replay(response.requestOptions, session.accessToken);
              return handler.resolve(retried);
            } on DioException catch (e) {
              return handler.resolve(e.response ?? response);
            }
          }

          // Refresh failed: the session is genuinely over.
          await _tokens.clear();
          onSessionExpired?.call();
        }

        return handler.next(response);
      },

      onError: (error, handler) async {
        // Same treatment when Dio classifies the 401 as an error.
        final status = error.response?.statusCode ?? 0;
        final isAuthCall = error.requestOptions.path.startsWith('/auth/');
        final alreadyRetried = error.requestOptions.extra['_retried'] == true;

        if (status == 401 && !isAuthCall && !alreadyRetried && refreshSession != null) {
          final session = await _refreshOnce();
          if (session != null) {
            try {
              final retried = await _replay(error.requestOptions, session.accessToken);
              return handler.resolve(retried);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          await _tokens.clear();
          onSessionExpired?.call();
        }

        return handler.next(error);
      },
    );
  }

  /// Coalesces concurrent refreshes into one.
  Future<AuthSession?> _refreshOnce() {
    final existing = _inFlightRefresh;
    if (existing != null) return existing;

    final future = _doRefresh().whenComplete(() {
      _inFlightRefresh = null;
    });
    _inFlightRefresh = future;
    return future;
  }

  Future<AuthSession?> _doRefresh() async {
    final refresher = refreshSession;
    if (refresher == null) return null;

    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return null;

    try {
      final session = await refresher(refreshToken);
      if (session != null) await _tokens.save(session);
      return session;
    } on Object {
      // Any failure here means the session cannot be recovered.
      return null;
    }
  }

  Future<Response<dynamic>> _replay(RequestOptions options, String token) {
    return _dio.request<dynamic>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      cancelToken: options.cancelToken,
      options: Options(
        method: options.method,
        headers: {...options.headers, 'Authorization': 'Bearer $token'},
        // Marks the replay so a second 401 cannot loop.
        extra: {...options.extra, '_retried': true},
      ),
    );
  }

  Interceptor _logInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('→ ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('← ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (e, handler) {
        debugPrint('✗ ${e.response?.statusCode ?? e.type.name} ${e.requestOptions.path}');
        return handler.next(e);
      },
    );
  }

  void close() => _dio.close(force: true);
}
