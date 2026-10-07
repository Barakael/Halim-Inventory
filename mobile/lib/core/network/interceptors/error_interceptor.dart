import 'package:dio/dio.dart';
import '../../error/app_exception.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        handler.reject(
          err.copyWith(
            error: NetworkException(message: 'Connection timed out'),
          ),
        );
        return;

      case DioExceptionType.connectionError:
        handler.reject(
          err.copyWith(
            error: NetworkException(message: 'No internet connection'),
          ),
        );
        return;

      case DioExceptionType.unknown:
      case DioExceptionType.badCertificate:
        final detail = err.error?.toString() ?? err.message ?? '';
        handler.reject(
          err.copyWith(
            error: NetworkException(
              message: detail.isNotEmpty
                  ? 'Cannot reach server: $detail'
                  : 'Cannot reach server — check connection and API URL',
            ),
          ),
        );
        return;

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final responseData = err.response?.data;
        final message = _extractMessage(responseData) ?? 'Server error';

        if (statusCode == 401) {
          handler.reject(
            err.copyWith(error: UnauthorizedException(message: message)),
          );
          return;
        }
        handler.reject(
          err.copyWith(
            error: ServerException(message: message, statusCode: statusCode),
          ),
        );
        return;

      default:
        handler.reject(
          err.copyWith(
            error: ServerException(
              message: err.message ?? 'An unexpected error occurred',
            ),
          ),
        );
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['message'] != null) return map['message'].toString();
      if (map['error'] != null) return map['error'].toString();
      if (map['errors'] is Map) {
        final errors = map['errors'] as Map;
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
    }
    return null;
  }
}
