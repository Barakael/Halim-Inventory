import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/api/api_service.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiService apiService;

  const AuthRemoteDataSourceImpl({required this.apiService});

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await apiService.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );
      
      print('API Result: $result'); // Debug log
      
      return result.fold(
        (failure) {
          print('API Failure: ${failure.message}'); // Debug log
          if (failure is UnauthorizedFailure) {
            throw UnauthorizedException(message: failure.message);
          }
          if (failure is NetworkFailure) {
            throw NetworkException(message: failure.message);
          }
          if (failure is ServerFailure) {
            throw ServerException(
              message: failure.message,
              statusCode: failure.statusCode,
            );
          }

          throw ServerException(message: failure.message);
        },
        (response) {
          print('API Response: $response'); // Debug log
          return AuthResponseModel.fromJson(response as Map<String, dynamic>);
        },
      );
    } catch (e) {
      print('Login Exception: $e'); // Debug log
      rethrow;
    }
  }

  @override
  Future<AuthResponseModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    String? companyId,
    String? roleId,
    String? roleName,
  }) {
    // Register endpoint not available in Laravel API
    throw UnimplementedError('Register functionality not implemented in backend');
  }

  @override
  Future<void> verifyPhone({
    required String phone,
    required String token,
  }) {
    // Phone verification endpoint not available in Laravel API
    throw UnimplementedError('Phone verification not implemented in backend');
  }

  @override
  Future<void> resendVerification({required String phone}) {
    // Resend verification endpoint not available in Laravel API
    throw UnimplementedError('Resend verification not implemented in backend');
  }

  @override
  Future<UserModel> getMe() async {
    final result = await apiService.get(ApiEndpoints.me);
    
    return result.fold(
      (failure) => throw Exception(failure.message),
      (response) => UserModel.fromJson(response as Map<String, dynamic>),
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    throw UnimplementedError(
      'Password change is not exposed on the current Laravel API',
    );
  }
}
