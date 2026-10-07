import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';

class UserRepositoryImpl implements UserRepository {
  final ApiClient _apiClient;

  UserRepositoryImpl(this._apiClient);

  @override
  Future<List<UserEntity>> getUsers() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        endpoint: '/users',
        parser: (json) => json as List<dynamic>,
      );
      return response.map((json) => UserModel.fromJson(json)).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Access denied. You need super_admin role to manage users.');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Users endpoint not found. Please check API configuration.');
      } else {
        throw Exception('Failed to load users: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  @override
  Future<UserEntity> createUser(Map<String, dynamic> userData) async {
    try {
      print('=== CREATE USER DEBUG ===');
      print('Endpoint: /users');
      print('Method: POST');
      print('Data being sent: $userData');
      print('Data type: ${userData.runtimeType}');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        endpoint: '/users',
        parser: (json) {
          print('Create user API response: $json');
          print('Response type: ${json.runtimeType}');
          return json as Map<String, dynamic>;
        },
        data: userData,
      );
      print('User created successfully: $response');
      return UserModel.fromJson(response);
    } on ServerException catch (e) {
      print('ServerException in createUser: ${e.message}');
      throw Exception('Failed to create user: ${e.message}');
    } on NetworkException catch (e) {
      print('NetworkException in createUser: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } on UnauthorizedException catch (e) {
      print('UnauthorizedException in createUser: ${e.message}');
      throw Exception('Unauthorized: ${e.message}');
    } catch (e) {
      print('Generic exception in createUser: $e');
      print('Exception type: ${e.runtimeType}');
      throw Exception('Failed to create user: $e');
    }
  }

  @override
  Future<UserEntity> updateUser(String id, Map<String, dynamic> userData) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        endpoint: '/users/$id',
        parser: (json) => json as Map<String, dynamic>,
        data: userData,
      );
      return UserModel.fromJson(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Access denied. You cannot modify this user.');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('User not found.');
      } else if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'] ?? {};
        final message = errors.values.first ?? 'Validation error';
        throw Exception('Validation failed: $message');
      } else {
        throw Exception('Failed to update user: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    try {
      await _apiClient.delete(endpoint: '/users/$id');
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Access denied. You cannot delete this user.');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('User not found.');
      } else {
        throw Exception('Failed to delete user: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
}
