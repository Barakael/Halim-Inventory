import '../../../../core/constants/api_endpoints.dart';
import '../../domain/entities/shop_entity.dart';
import '../../domain/repositories/shop_repository.dart';
import '../models/shop_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/error/app_exception.dart';

class ShopRepositoryImpl implements ShopRepository {
  final ApiClient _apiClient;

  ShopRepositoryImpl(this._apiClient);

  @override
  Future<List<ShopEntity>> getShops() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        endpoint: '/shops',
        parser: (json) => json as List<dynamic>,
      );
      return response.map((json) => ShopModel.fromJson(json)).toList();
    } on ServerException catch (e) {
      throw Exception('Failed to load shops: ${e.message}');
    } on NetworkException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on UnauthorizedException catch (e) {
      throw Exception('Unauthorized: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load shops: $e');
    }
  }

  @override
  Future<ShopEntity> createShop({
    required String name,
    required String address,
    required String phone,
    required String email,
    double taxRate = 0.0,
    String currency = 'TZS',
    required String ownerName,
    required String ownerEmail,
    required String ownerPassword,
  }) async {
    try {
      print('[DEBUG] Creating shop with data: {');
      print('  name: $name,');
      print('  address: $address,');
      print('  phone: $phone,');
      print('  email: $email,');
      print('  tax_rate: $taxRate,');
      print('  currency: $currency,');
      print('  owner_name: $ownerName,');
      print('  owner_email: $ownerEmail,');
      print('  owner_password: [HIDDEN]');
      print('}');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        endpoint: '/shops',
        parser: (json) {
          print('[DEBUG] Raw API response: $json');
          if (json == null) {
            print('[DEBUG] Response is null!');
            throw Exception('API response is null');
          }
          if (json is! Map<String, dynamic>) {
            print('[DEBUG] Response is not a Map: ${json.runtimeType}');
            throw Exception('API response is not a Map');
          }
          if (!json.containsKey('shop')) {
            print('[DEBUG] Response does not contain "shop" key. Keys: ${json.keys}');
            throw Exception('API response does not contain shop data');
          }
          final shopData = json['shop'] as Map<String, dynamic>;
          print('[DEBUG] Shop data extracted: $shopData');
          return shopData;
        },
        data: {
          'name': name,
          'address': address,
          'phone': phone,
          'email': email,
          'tax_rate': taxRate,
          'currency': currency,
          'owner_name': ownerName,
          'owner_email': ownerEmail,
          'owner_password': ownerPassword,
        },
      );
      print('[DEBUG] Creating ShopModel from response...');
      return ShopModel.fromJson(response);
    } on ServerException catch (e) {
      print('[DEBUG] ServerException: ${e.message}');
      throw Exception('Failed to create shop: ${e.message}');
    } on NetworkException catch (e) {
      print('[DEBUG] NetworkException: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } on UnauthorizedException catch (e) {
      print('[DEBUG] UnauthorizedException: ${e.message}');
      throw Exception('Unauthorized: ${e.message}');
    } catch (e) {
      print('[DEBUG] Generic exception: $e');
      throw Exception('Failed to create shop: $e');
    }
  }

  @override
  Future<ShopEntity> updateShop({
    required int id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? currency,
    String? status,
  }) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        endpoint: '/shops/$id',
        parser: (json) => json as Map<String, dynamic>,
        data: {
          if (name != null) 'name': name,
          if (address != null) 'address': address,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (currency != null) 'currency': currency,
          if (status != null) 'status': status,
        },
      );
      return ShopModel.fromJson(response);
    } on ServerException catch (e) {
      throw Exception('Failed to update shop: ${e.message}');
    } on NetworkException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on UnauthorizedException catch (e) {
      throw Exception('Unauthorized: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update shop: $e');
    }
  }

  @override
  Future<void> deleteShop(int id) async {
    try {
      await _apiClient.delete(endpoint: '/shops/$id');
    } on ServerException catch (e) {
      throw Exception('Failed to delete shop: ${e.message}');
    } on NetworkException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on UnauthorizedException catch (e) {
      throw Exception('Unauthorized: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete shop: $e');
    }
  }

  @override
  Future<ShopEntity?> getCurrentShop() async {
    try {
      final response = await _apiClient.get<dynamic>(
        endpoint: ApiEndpoints.settings,
        parser: (json) => json,
      );

      Map<String, dynamic>? map;
      if (response is Map<String, dynamic>) {
        map = response;
      } else if (response is Map) {
        map = Map<String, dynamic>.from(response);
      }

      if (map == null) return null;
      return ShopModel.fromApi(map);
    } on ServerException catch (e) {
      throw Exception('Failed to load shop settings: ${e.message}');
    } on NetworkException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on UnauthorizedException catch (e) {
      throw Exception('Unauthorized: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load shop settings: $e');
    }
  }

  @override
  Future<ShopEntity> updateCurrentShop({
    String? name,
    String? address,
    String? phone,
    String? email,
    double? taxRate,
    String? currency,
    String? tin,
    String? vrn,
    String? mobile,
    String? location,
    String? taxOffice,
  }) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        endpoint: ApiEndpoints.settings,
        parser: (json) => json as Map<String, dynamic>,
        data: {
          if (name != null) 'name': name,
          if (address != null) 'address': address,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (taxRate != null) 'tax_rate': taxRate,
          if (currency != null) 'currency': currency,
          if (tin != null) 'tin': tin,
          if (vrn != null) 'vrn': vrn,
          if (mobile != null) 'mobile': mobile,
          if (location != null) 'location': location,
          if (taxOffice != null) 'tax_office': taxOffice,
        },
      );
      return ShopModel.fromApi(response);
    } on ServerException catch (e) {
      throw Exception('Failed to update shop: ${e.message}');
    } on NetworkException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on UnauthorizedException catch (e) {
      throw Exception('Unauthorized: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update shop: $e');
    }
  }

  @override
  Future<ShopEntity> getShop(int id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        endpoint: '/shops/$id',
        parser: (json) => json['shop'] as Map<String, dynamic>,
      );
      return ShopModel.fromJson(response);
    } on ServerException catch (e) {
      throw Exception('Failed to load shop: ${e.message}');
    } on NetworkException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on UnauthorizedException catch (e) {
      throw Exception('Unauthorized: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load shop: $e');
    }
  }
}
