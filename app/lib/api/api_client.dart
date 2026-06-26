import 'package:dio/dio.dart';

import '../config.dart';

/// A friendly, presentable error. Screens catch this and show `message`
/// directly — it never contains stack traces or raw server internals.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  /// True when the failure is an expired/invalid token, so callers can log out.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Wraps a single [Dio] instance: base URL, sensible timeouts, a bearer-token
/// interceptor, and translation of [DioException]s into [ApiException]s with
/// human-readable messages.
class ApiClient {
  final Dio dio;
  String? _token;

  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            // Don't let dio throw on its own; we map statuses ourselves.
            validateStatus: (status) => status != null && status < 500,
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// Set/clear the bearer token attached to every subsequent request.
  set token(String? value) => _token = value;

  /// Convert any thrown object from a request into a presentable [ApiException].
  /// Used by the API wrappers so screens only ever see friendly messages.
  ApiException toApiException(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return const ApiException(
            'The server took too long to respond. Please try again.',
          );
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          return const ApiException(
            "Can't reach the server. Check your connection and the backend URL.",
          );
        default:
          final response = error.response;
          if (response != null) {
            return _fromResponse(response.statusCode, response.data);
          }
          return const ApiException('Something went wrong. Please try again.');
      }
    }
    return const ApiException('Something went wrong. Please try again.');
  }

  /// Build an exception from a (non-2xx) response we received and validated.
  static ApiException fromStatus(int? status, Object? data) =>
      _fromResponse(status, data);

  static ApiException _fromResponse(int? status, Object? data) {
    final detail = _detail(data);
    switch (status) {
      case 401:
        return ApiException(
          detail.isNotEmpty ? detail : 'Invalid email or password.',
          401,
        );
      case 403:
        return ApiException(
          detail.isNotEmpty ? detail : 'You are not allowed to do that.',
          403,
        );
      case 404:
        return ApiException(
          detail.isNotEmpty ? detail : 'Not found.',
          404,
        );
      case 409:
        return ApiException(
          detail.isNotEmpty ? detail : 'That already exists.',
          409,
        );
      case 422:
        return ApiException(
          detail.isNotEmpty ? detail : 'Please check the details and try again.',
          422,
        );
      default:
        return ApiException(
          detail.isNotEmpty
              ? detail
              : 'Something went wrong on the server. Please try again.',
          status,
        );
    }
  }

  /// Extract a message from a FastAPI error body. `detail` is a string for
  /// HTTPExceptions and a list of `{loc, msg, ...}` for 422 validation errors.
  static String _detail(Object? data) {
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
    }
    return '';
  }
}
