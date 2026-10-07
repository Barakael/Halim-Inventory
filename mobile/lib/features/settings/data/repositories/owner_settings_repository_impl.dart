import '../../../shops/data/models/shop_model.dart';
import '../../../shops/domain/entities/shop_entity.dart';
import '../../domain/repositories/owner_settings_repository.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/error/app_exception.dart';

class OwnerSettingsRepositoryImpl implements OwnerSettingsRepository {
  final ApiClient _apiClient;

  OwnerSettingsRepositoryImpl(this._apiClient);

  List<dynamic> _asList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map && raw['data'] is List) return raw['data'] as List;
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw Exception('Invalid API response');
  }

  BranchEntity _branchFrom(Map<String, dynamic> json) {
    return BranchEntity(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString(),
    );
  }

  @override
  Future<ShopEntity?> getCurrentShop() async {
    try {
      final response = await _apiClient.get<dynamic>(
        endpoint: ApiEndpoints.settings,
        parser: (json) => json,
      );
      if (response is! Map) return null;
      return ShopModel.fromApi(_asMap(response));
    } on ServerException catch (e) {
      throw Exception(e.message);
    } on NetworkException catch (e) {
      throw Exception(e.message);
    } on UnauthorizedException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to load shop: $e');
    }
  }

  @override
  Future<List<BranchEntity>> getBranches() async {
    try {
      final raw = await _apiClient.get<dynamic>(
        endpoint: ApiEndpoints.branches,
        parser: (json) => json,
      );
      return _asList(raw)
          .whereType<Map>()
          .map((e) => _branchFrom(Map<String, dynamic>.from(e)))
          .toList();
    } on ServerException catch (e) {
      throw Exception(e.message);
    } on NetworkException catch (e) {
      throw Exception(e.message);
    } on UnauthorizedException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to load branches: $e');
    }
  }

  @override
  Future<BranchEntity> createBranch({
    required String name,
    required String address,
    String? phone,
  }) async {
    try {
      final raw = await _apiClient.post<dynamic>(
        endpoint: ApiEndpoints.branches,
        data: {
          'name': name,
          'address': address,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
        parser: (json) => json,
      );
      return _branchFrom(_asMap(raw));
    } on ServerException catch (e) {
      throw Exception(e.message);
    } on NetworkException catch (e) {
      throw Exception(e.message);
    } on UnauthorizedException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to create branch: $e');
    }
  }

  @override
  Future<void> deleteBranch(int id) async {
    try {
      await _apiClient.delete(endpoint: ApiEndpoints.branchById('$id'));
    } on ServerException catch (e) {
      throw Exception(e.message);
    } on NetworkException catch (e) {
      throw Exception(e.message);
    } on UnauthorizedException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to delete branch: $e');
    }
  }

  @override
  Future<SubscriptionEntity> getSubscription() async {
    try {
      final raw = await _apiClient.get<dynamic>(
        endpoint: ApiEndpoints.subscriptions,
        parser: (json) => json,
      );
      Map<String, dynamic>? sub;
      if (raw is Map && raw['id'] != null) {
        sub = Map<String, dynamic>.from(raw);
      } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
        sub = Map<String, dynamic>.from(raw.first as Map);
      }
      if (sub == null) {
        return SubscriptionEntity(
          planName: '',
          price: 0,
          status: '',
          nextDueDate: '',
          paymentHistory: const [],
        );
      }
      return SubscriptionEntity(
        planName: sub['plan_name']?.toString() ?? '',
        price: (sub['plan_price'] as num?)?.toDouble() ?? 0,
        status: sub['status']?.toString() ?? '',
        nextDueDate: sub['next_due_at']?.toString() ?? '',
        paymentHistory: const [],
      );
    } on ServerException catch (e) {
      throw Exception(e.message);
    } on NetworkException catch (e) {
      throw Exception(e.message);
    } on UnauthorizedException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to load subscription: $e');
    }
  }
}
