import 'package:freezed_annotation/freezed_annotation.dart';

part 'role_model.freezed.dart';
part 'role_model.g.dart';

@freezed
class RoleModel with _$RoleModel {
  const factory RoleModel({
    required String id,
    required String name,
    String? description,
  }) = _RoleModel;

  factory RoleModel.fromJson(Map<String, dynamic> json) =>
      _$RoleModelFromJson(json);
}

class AppRoles {
  static const String superAdmin = 'Super Admin';
  static const String businessOwner = 'Business Owner';
  static const String cashier = 'Cashier';

  static List<String> get allRoles => [
        superAdmin,
        businessOwner,
        cashier,
      ];

  static List<String> get registerableRoles => [
        businessOwner,
        cashier,
      ];
}
