import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Verbose API logging — debug/profile only. Never log bodies or tokens in release.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!kReleaseMode) {
      debugPrint('[API] ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!kReleaseMode) {
      debugPrint(
        '[API] ${response.statusCode} ${response.requestOptions.uri}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!kReleaseMode) {
      debugPrint(
        '[API ERROR] ${err.response?.statusCode ?? err.type} '
        '${err.requestOptions.uri}',
      );
    }
    handler.next(err);
  }
}
