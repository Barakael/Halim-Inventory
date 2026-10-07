import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import '../error/failure.dart';
import '../network/api_path.dart';

class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  ApiService({
    required Dio dio,
    required FlutterSecureStorage secureStorage,
  })  : _dio = dio,
        _secureStorage = secureStorage {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data is FormData) {
            options.headers.remove(Headers.contentTypeHeader);
            options.contentType = Headers.multipartFormDataContentType;
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _secureStorage.delete(key: 'auth_token');
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Either<Failure, T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        resolveApiPath(path),
        queryParameters: queryParameters,
        options: options,
      );
      if (fromJson != null) return Right(fromJson(response.data));
      return Right(response.data as T);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  Future<Either<Failure, T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        resolveApiPath(path),
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      if (fromJson != null) return Right(fromJson(response.data));
      return Right(response.data as T);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  Future<Either<Failure, T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        resolveApiPath(path),
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      if (fromJson != null) return Right(fromJson(response.data));
      return Right(response.data as T);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  Future<Either<Failure, T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        resolveApiPath(path),
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      if (fromJson != null) return Right(fromJson(response.data));
      // Avoid casting JSON bodies to void (breaks product delete).
      return Right(response.data as T);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  Future<Either<Failure, T>> upload<T>(
    String path, {
    required String filePath,
    String fieldName = 'file',
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final fileName = filePath.replaceAll('\\', '/').split('/').last;
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath, filename: fileName),
        ...?data,
      });
      final response = await _dio.post(
        resolveApiPath(path),
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
        ),
      );
      if (fromJson != null) return Right(fromJson(response.data));
      return Right(response.data as T);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  Failure _handleDioError(DioException e) {
    print('DioException Type: ${e.type}');
    print('DioException Message: ${e.message}');
    print('DioException Response: ${e.response}');
    print('DioException Data: ${e.response?.data}');
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return const NetworkFailure(message: 'Connection timeout');
      case DioExceptionType.sendTimeout:
        return const NetworkFailure(message: 'Send timeout');
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure(message: 'Receive timeout');
      case DioExceptionType.badResponse:
        final message = _extractErrorMessage(e.response?.data);
        if (e.response?.statusCode == 401) return UnauthorizedFailure();
        if (e.response?.statusCode == 422) {
          return ServerFailure(
            message: message.isEmpty ? 'Validation failed' : message,
            statusCode: 422,
          );
        }
        return ServerFailure(message: message, statusCode: e.response?.statusCode);
      case DioExceptionType.cancel:
        return const UnexpectedFailure(message: 'Request cancelled');
      case DioExceptionType.connectionError:
        return const NetworkFailure(message: 'Connection error - check if server is running');
      case DioExceptionType.badCertificate:
        return const NetworkFailure(message: 'Bad SSL certificate');
      case DioExceptionType.unknown:
        return UnexpectedFailure(message: e.message ?? 'Network error - check server connection and URL');
      default:
        return UnexpectedFailure(message: e.message ?? 'Unknown error occurred');
    }
  }

  String _extractErrorMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('message')) {
        return responseData['message'].toString();
      }
      if (responseData.containsKey('errors')) {
        final errors = responseData['errors'];
        if (errors is Map<String, dynamic>) {
          final firstErrorKey = errors.keys.firstOrNull;
          if (firstErrorKey != null && errors[firstErrorKey] is List) {
            final errorList = errors[firstErrorKey] as List;
            if (errorList.isNotEmpty) return errorList.first.toString();
          }
        }
      }
      if (responseData.containsKey('error')) {
        return responseData['error'].toString();
      }
    }
    return responseData?.toString() ?? 'Unknown error';
  }
}