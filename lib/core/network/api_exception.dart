// ─────────────────────────────────────────────────────────────────────────────
// API EXCEPTIONS
//
// A typed failure with a message that is already safe to show a user.
//
// This is what lets every screen have a real error state. The previous code either
// swallowed failures entirely (`catch (_) {}` in home_screen and
// slot_selection_screen, so a network error rendered as an empty list with no
// message) or dumped the raw exception into a SnackBar ("Error connecting to
// server: SocketException: Failed host lookup...").
// ─────────────────────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';

/// Machine-readable failure kinds, so UI can branch without parsing strings.
enum ApiErrorKind {
  /// No usable connection.
  offline,

  /// The request took too long.
  timeout,

  /// 401 — not signed in, or the session ended.
  unauthenticated,

  /// 403 — signed in, but not allowed.
  forbidden,

  /// 404.
  notFound,

  /// 409 — a business conflict: the slot went, the hold expired.
  conflict,

  /// 422 — field-level validation.
  validation,

  /// 429.
  rateLimited,

  /// 5xx.
  server,

  /// 501 — the endpoint exists but its phase has not landed.
  notImplemented,

  /// Anything else.
  unknown,
}

class ApiException implements Exception {
  ApiException({
    required this.kind,
    required this.message,
    this.code,
    this.statusCode,
    this.fieldErrors,
    this.requestId,
    this.retryAfter,
  });

  final ApiErrorKind kind;

  /// Safe to display. The backend authors these deliberately; this class never
  /// surfaces a raw exception string.
  final String message;

  /// Stable backend code, e.g. `SLOT_UNAVAILABLE`, `HOLD_EXPIRED`.
  final String? code;

  final int? statusCode;

  /// Field name → messages, for 422 responses.
  final Map<String, List<String>>? fieldErrors;

  /// Correlates with server logs; shown in diagnostics, not to users.
  final String? requestId;

  final Duration? retryAfter;

  /// True when trying again might plausibly work.
  bool get isRetryable =>
      kind == ApiErrorKind.offline ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.server ||
      kind == ApiErrorKind.rateLimited;

  /// True when the user must sign in again.
  bool get requiresReauth => kind == ApiErrorKind.unauthenticated;

  /// Headline for an error state.
  String get title {
    switch (kind) {
      case ApiErrorKind.offline:
        return 'No connection';
      case ApiErrorKind.timeout:
        return 'That took too long';
      case ApiErrorKind.unauthenticated:
        return 'Please sign in';
      case ApiErrorKind.forbidden:
        return 'Not available';
      case ApiErrorKind.notFound:
        return 'Not found';
      case ApiErrorKind.conflict:
        return 'Just missed it';
      case ApiErrorKind.validation:
        return 'Check the details';
      case ApiErrorKind.rateLimited:
        return 'Slow down a moment';
      case ApiErrorKind.notImplemented:
        return 'Coming soon';
      case ApiErrorKind.server:
      case ApiErrorKind.unknown:
        return 'Something went wrong';
    }
  }

  /// Builds from a Dio failure, preferring the backend's own message.
  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    final requestId =
        response?.headers.value('x-request-id') ?? _extractRequestId(response?.data);

    // Transport-level failures never have a useful body.
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          kind: ApiErrorKind.timeout,
          message: 'The server is taking too long to respond. Please try again.',
          requestId: requestId,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          kind: ApiErrorKind.offline,
          message: 'Check your internet connection and try again.',
          requestId: requestId,
        );
      case DioExceptionType.cancel:
        return ApiException(
          kind: ApiErrorKind.unknown,
          message: 'Request cancelled.',
          requestId: requestId,
        );
      default:
        break;
    }

    final status = response?.statusCode ?? 0;
    final parsed = _parseErrorBody(response?.data);

    return ApiException(
      kind: _kindFor(status),
      message: parsed.message ?? _defaultMessageFor(status),
      code: parsed.code,
      statusCode: status,
      fieldErrors: parsed.fieldErrors,
      requestId: requestId ?? parsed.requestId,
      retryAfter: _parseRetryAfter(response),
    );
  }

  factory ApiException.offline() => ApiException(
        kind: ApiErrorKind.offline,
        message: 'Check your internet connection and try again.',
      );

  factory ApiException.unknown([Object? cause]) => ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Something went wrong. Please try again.',
        code: cause?.runtimeType.toString(),
      );

  static ApiErrorKind _kindFor(int status) {
    if (status == 401) return ApiErrorKind.unauthenticated;
    if (status == 403) return ApiErrorKind.forbidden;
    if (status == 404) return ApiErrorKind.notFound;
    if (status == 409) return ApiErrorKind.conflict;
    if (status == 422 || status == 400) return ApiErrorKind.validation;
    if (status == 429) return ApiErrorKind.rateLimited;
    if (status == 501) return ApiErrorKind.notImplemented;
    if (status >= 500) return ApiErrorKind.server;
    return ApiErrorKind.unknown;
  }

  static String _defaultMessageFor(int status) {
    if (status >= 500) return 'Our server had a problem. Please try again shortly.';
    if (status == 404) return 'We could not find what you were looking for.';
    return 'Something went wrong. Please try again.';
  }

  /// Parses `{ error: { code, message, details, request_id } }`.
  static _ParsedError _parseErrorBody(dynamic data) {
    if (data is! Map) return const _ParsedError();

    final error = data['error'];
    if (error is! Map) {
      // Legacy `/api/*` routes return a bare `{ message }`.
      final legacy = data['message'];
      return _ParsedError(message: legacy is String ? legacy : null);
    }

    Map<String, List<String>>? fields;
    final details = error['details'];
    if (details is Map && details['fields'] is Map) {
      fields = <String, List<String>>{};
      (details['fields'] as Map).forEach((key, value) {
        // Strip the `body.` / `query.` prefix the server adds — a form field is
        // named `phone`, not `body.phone`.
        final name = key.toString().split('.').last;
        if (value is List) {
          fields![name] = value.map((v) => v.toString()).toList();
        } else if (value != null) {
          fields![name] = [value.toString()];
        }
      });
    }

    return _ParsedError(
      code: error['code']?.toString(),
      message: error['message']?.toString(),
      fieldErrors: fields,
      requestId: error['request_id']?.toString(),
    );
  }

  static String? _extractRequestId(dynamic data) {
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['request_id']?.toString();
    }
    return null;
  }

  static Duration? _parseRetryAfter(Response<dynamic>? response) {
    final header = response?.headers.value('retry-after');
    if (header != null) {
      final seconds = int.tryParse(header);
      if (seconds != null) return Duration(seconds: seconds);
    }
    final data = response?.data;
    if (data is Map && data['error'] is Map) {
      final details = (data['error'] as Map)['details'];
      if (details is Map && details['retry_after_seconds'] != null) {
        final s = int.tryParse(details['retry_after_seconds'].toString());
        if (s != null) return Duration(seconds: s);
      }
    }
    return null;
  }

  /// Message for a specific form field, if the server flagged one.
  String? fieldError(String field) => fieldErrors?[field]?.first;

  @override
  String toString() =>
      'ApiException(${kind.name}${code != null ? ', $code' : ''}): $message';
}

class _ParsedError {
  const _ParsedError({this.code, this.message, this.fieldErrors, this.requestId});
  final String? code;
  final String? message;
  final Map<String, List<String>>? fieldErrors;
  final String? requestId;
}

/// Narrows an arbitrary error to an [ApiException].
///
/// `AsyncValue.error` is typed as `Object`, so every screen that renders an error
/// state needs this conversion. It was written out by hand in each of them, which
/// meant the fallback message could drift between screens for the same failure.
ApiException asApiException(Object? error) {
  if (error is ApiException) return error;
  return ApiException.unknown(error);
}
