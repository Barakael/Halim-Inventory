import 'package:equatable/equatable.dart';

import '../../../shops/domain/entities/shop_entity.dart';

class UserEntity extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final bool isVerified;
  final String roleId;
  final String roleName;
  final String? companyId;
  final ShopEntity? shop;
  final List<String> permissions;

  const UserEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.isVerified,
    required this.roleId,
    required this.roleName,
    this.companyId,
    this.shop,
    this.permissions = const [],
  });

  String get fullName => '$firstName $lastName';

  bool get isSuperAdmin => roleName == 'Super Admin';
  bool get isBusinessOwner => roleName == 'Business Owner';
  bool get isCashier => roleName == 'Cashier';

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  List<Object?> get props => [id, email, roleName, companyId, shop];
}
