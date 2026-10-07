import '../../domain/entities/staff_entity.dart';
import '../../domain/repositories/staff_repository.dart';
import '../models/staff_model.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

class StaffRepositoryImpl implements StaffRepository {
  final ApiClient _apiClient;

  StaffRepositoryImpl(this._apiClient);

  @override
  Future<List<StaffEntity>> getStaff() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        endpoint: ApiEndpoints.staff,
        parser: (json) {
          if (json is List) return json;
          if (json is Map<String, dynamic> && json['data'] is List) {
            return json['data'] as List<dynamic>;
          }
          return <dynamic>[];
        },
      );
      return response
          .map((e) => StaffModel.fromApi(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load staff: $e');
    }
  }

  @override
  Future<StaffEntity> createStaff({
    required String name,
    required String email,
    required String password,
    required int branchId,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        endpoint: ApiEndpoints.staff,
        parser: (json) {
          if (json is Map<String, dynamic>) {
            if (json['data'] is Map<String, dynamic>) {
              return json['data'] as Map<String, dynamic>;
            }
            return json;
          }
          throw Exception('Invalid staff response');
        },
        data: {
          'name': name,
          'email': email,
          'password': password,
          'branch_id': branchId,
        },
      );
      return StaffModel.fromApi(response);
    } catch (e) {
      throw Exception('Failed to create staff: $e');
    }
  }

  @override
  Future<StaffEntity> updateStaff({
    required int id,
    required String name,
    required String email,
    String? password,
    int? branchId,
  }) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        endpoint: ApiEndpoints.staffById(id.toString()),
        parser: (json) {
          if (json is Map<String, dynamic>) {
            if (json['data'] is Map<String, dynamic>) {
              return json['data'] as Map<String, dynamic>;
            }
            return json;
          }
          throw Exception('Invalid staff response');
        },
        data: {
          'name': name,
          'email': email,
          if (password != null && password.isNotEmpty) 'password': password,
          if (branchId != null) 'branch_id': branchId,
        },
      );
      return StaffModel.fromApi(response);
    } catch (e) {
      throw Exception('Failed to update staff: $e');
    }
  }

  @override
  Future<void> deleteStaff(int id) async {
    try {
      await _apiClient.delete(endpoint: ApiEndpoints.staffById(id.toString()));
    } catch (e) {
      throw Exception('Failed to delete staff: $e');
    }
  }
}
