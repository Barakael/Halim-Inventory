import 'package:json_annotation/json_annotation.dart';
import '../../../shops/data/models/shop_model.dart';
import '../../domain/entities/user_entity.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final bool isVerified;
  final RoleModel? role;
  final String? companyId;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final ShopModel? shop;
  final List<String>? permissions;

  const UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.isVerified,
    this.role,
    this.companyId,
    this.shop,
    this.permissions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    final shopRaw = copy.remove('shop');
    final base = _$UserModelFromJson(copy);
    return UserModel(
      id: base.id,
      firstName: base.firstName,
      lastName: base.lastName,
      email: base.email,
      phone: base.phone,
      avatarUrl: base.avatarUrl,
      isVerified: base.isVerified,
      role: base.role,
      companyId: base.companyId,
      shop: shopRaw is Map<String, dynamic>
          ? ShopModel.fromApi(shopRaw)
          : null,
      permissions: base.permissions,
    );
  }

  Map<String, dynamic> toJson() {
    final j = _$UserModelToJson(UserModel(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      isVerified: isVerified,
      role: role,
      companyId: companyId,
      shop: null,
      permissions: permissions,
    ));
    if (shop != null) {
      j['shop'] = shop!.toApiJson();
    }
    return j;
  }

  UserEntity toEntity() => UserEntity(
        id: id,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        avatarUrl: avatarUrl,
        isVerified: isVerified,
        roleId: role?.id ?? '',
        roleName: role?.name ?? '',
        companyId: companyId,
        shop: shop,
        permissions: permissions ?? [],
      );
}

@JsonSerializable()
class RoleModel {
  final String id;
  final String name;

  const RoleModel({required this.id, required this.name});

  factory RoleModel.fromJson(Map<String, dynamic> json) =>
      _$RoleModelFromJson(json);

  Map<String, dynamic> toJson() => _$RoleModelToJson(this);
}

@JsonSerializable()
class AuthResponseModel {
  final String token;
  final UserModel user;

  const AuthResponseModel({required this.token, required this.user});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    // Custom parsing to handle Laravel API response structure
    final userJson = json['user'] as Map<String, dynamic>;

    ShopModel? shopModel;
    final shopRaw = userJson['shop'];
    if (shopRaw is Map<String, dynamic>) {
      shopModel = ShopModel.fromApi(shopRaw);
    }

    final user = UserModel(
      id: userJson['id']?.toString() ?? '',
      firstName: _extractFirstName(userJson['name']?.toString() ?? ''),
      lastName: _extractLastName(userJson['name']?.toString() ?? ''),
      email: userJson['email']?.toString() ?? '',
      phone: userJson['phone']?.toString(),
      avatarUrl: userJson['avatar_url']?.toString(),
      isVerified: userJson['email_verified_at'] != null,
      role: userJson['role'] != null
          ? RoleModel(
              id: userJson['role']?.toString() ?? '',
              name: userJson['role']?.toString() ?? '',
            )
          : null,
      companyId: userJson['shop_id']?.toString(),
      shop: shopModel,
      permissions: null, // Laravel doesn't provide permissions in login response
    );

    return AuthResponseModel(
      token: json['token']?.toString() ?? '',
      user: user,
    );
  }

  static String _extractFirstName(String fullName) {
    final parts = fullName.split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  static String _extractLastName(String fullName) {
    final parts = fullName.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  Map<String, dynamic> toJson() => _$AuthResponseModelToJson(this);
}
