import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config.dart';
import 'token_store.dart';

/// An error from the API or the network, with the server's message when there
/// is one. [code] carries the backend's machine-readable code
/// (e.g. TWO_FACTOR_REQUIRED) and is 'NETWORK' when no response was received.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code});

  final String message;
  final int? status;
  final String? code;

  bool get isNetwork => code == 'NETWORK';

  @override
  String toString() => message;
}

/// Thin Dio wrapper that
///  - unwraps the backend's `{ success, message, data }` envelope,
///  - attaches the bearer token,
///  - transparently refreshes an expired access token once (single-flight, so
///    parallel requests share one refresh; the backend rotates refresh tokens
///    and would reject a second concurrent use),
///  - turns every failure into an [ApiException].
class ApiClient {
  ApiClient(this._tokens) {
    final options = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    );
    _dio = Dio(options);
    _bare = Dio(options.copyWith());

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokens.access;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final isAuthCall = request.path.startsWith('/auth/');
          final alreadyRetried = request.extra['retried'] == true;
          if (error.response?.statusCode == 401 &&
              !isAuthCall &&
              !alreadyRetried &&
              _tokens.refresh != null) {
            final refreshed = await _refreshTokens();
            if (refreshed) {
              request.extra['retried'] = true;
              request.headers['Authorization'] = 'Bearer ${_tokens.access}';
              try {
                final response = await _dio.fetch<dynamic>(request);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStore _tokens;
  late final Dio _dio;

  /// A client with no auth header and no interceptors, used for the refresh
  /// call and for uploading straight to storage (presigned URLs must not carry
  /// our bearer token).
  late final Dio _bare;

  /// Called when the refresh token is no longer valid and the user must sign in again.
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  Future<bool> _refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = _tokens.refresh;
    if (refreshToken == null) return false;
    try {
      final response = await _bare.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is Map &&
          data['accessToken'] is String &&
          data['refreshToken'] is String) {
        await _tokens.save(
          access: data['accessToken'] as String,
          refresh: data['refreshToken'] as String,
        );
        return true;
      }
      return false;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Only a definitive rejection ends the session; a flaky network must not log people out.
      if (status == 400 || status == 401 || status == 403) {
        await _tokens.clear();
        onSessionExpired?.call();
      }
      return false;
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      final json = response.data;
      if (json is Map && json.containsKey('data')) return json['data'];
      return json;
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// PUTs raw bytes to a presigned storage URL (photos, documents, avatar).
  Future<void> putBytes(String url, Uint8List bytes, String contentType) async {
    try {
      await _bare.put<dynamic>(
        url,
        data: Stream<List<int>>.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
    } on DioException catch (e) {
      throw _toException(e, fallbackMessage: 'Upload failed');
    }
  }

  ApiException _toException(DioException e, {String? fallbackMessage}) {
    final response = e.response;
    if (response == null) {
      return ApiException(
        'Could not reach the server',
        code: 'NETWORK',
      );
    }
    String? message;
    String? code;
    final data = response.data;
    if (data is Map) {
      if (data['message'] is String) message = data['message'] as String;
      final errors = data['errors'];
      if (errors is Map && errors['code'] is String) {
        code = errors['code'] as String;
      } else if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map && first['msg'] is String) {
          message = first['msg'] as String;
        }
      }
    }
    return ApiException(
      message ?? fallbackMessage ?? 'Something went wrong (${response.statusCode})',
      status: response.statusCode,
      code: code,
    );
  }
}
