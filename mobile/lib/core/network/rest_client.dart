import 'package:dio/dio.dart';
import '../error/app_exception.dart';
import 'api_client.dart';
import 'api_path.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import '../storage/secure_storage.dart';

class RestClient implements ApiClient {
  final Dio _dio;

  RestClient({required String baseUrl, required SecureStorage secureStorage})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Accept': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.addAll([
      AuthInterceptor(secureStorage: secureStorage),
      ErrorInterceptor(),
      LoggingInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  Never _rethrow(Object e) {
    if (e is ServerException ||
        e is NetworkException ||
        e is UnauthorizedException) {
      throw e;
    }
    if (e is DioException) {
      final inner = e.error;
      if (inner is ServerException ||
          inner is NetworkException ||
          inner is UnauthorizedException) {
        throw inner!;
      }
      throw ServerException(
        message: e.message ?? inner?.toString() ?? e.toString(),
        statusCode: e.response?.statusCode,
      );
    }
    throw ServerException(message: e.toString());
  }

  @override
  Future<T> get<T>({
    required String endpoint,
    required T Function(dynamic json) parser,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        resolveApiPath(endpoint),
        queryParameters: queryParameters,
      );
      return parser(_extractData(response.data));
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<T> post<T>({
    required String endpoint,
    required T Function(dynamic json) parser,
    dynamic data,
  }) async {
    try {
      final response = await _dio.post(resolveApiPath(endpoint), data: data);
      return parser(_extractData(response.data));
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<T> put<T>({
    required String endpoint,
    required T Function(dynamic json) parser,
    dynamic data,
  }) async {
    try {
      final response = await _dio.put(resolveApiPath(endpoint), data: data);
      return parser(_extractData(response.data));
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<T> patch<T>({
    required String endpoint,
    required T Function(dynamic json) parser,
    dynamic data,
  }) async {
    try {
      final response = await _dio.patch(resolveApiPath(endpoint), data: data);
      return parser(_extractData(response.data));
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> delete({required String endpoint}) async {
    try {
      await _dio.delete(resolveApiPath(endpoint));
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<int>> downloadBytes({required String endpoint}) async {
    try {
      final response = await _dio.get<List<int>>(
        resolveApiPath(endpoint),
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? [];
    } catch (e) {
      _rethrow(e);
    }
  }

  dynamic _extractData(dynamic responseBody) {
    if (responseBody is Map<String, dynamic> &&
        responseBody.containsKey('data')) {
      return responseBody['data'];
    }
    return responseBody;
  }
}
