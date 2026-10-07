import 'package:dio/dio.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API] ${options.method} ${options.uri}');
    if (options.data != null) {
      print('[API] Request data: ${options.data}');
    }
    if (options.headers.containsKey('Authorization')) {
      final auth = options.headers['Authorization'].toString();
      print(
        '[API] Auth: ${auth.length > 24 ? auth.substring(0, 24) : auth}...',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API] ${response.statusCode} ${response.requestOptions.uri}');
    print('[API] Response data: ${response.data}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API ERROR] ${err.requestOptions.uri}');
    print('[API ERROR] Type: ${err.type}');
    print('[API ERROR] Message: ${err.message}');
    print('[API ERROR] Underlying: ${err.error}');
    print('[API ERROR] Response: ${err.response?.data}');
    print('[API ERROR] Status: ${err.response?.statusCode}');
    handler.next(err);
  }
}
