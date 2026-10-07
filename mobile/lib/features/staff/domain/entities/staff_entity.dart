import 'package:equatable/equatable.dart';

class StaffEntity extends Equatable {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? roleName;
  final String? shopName;
  final int? branchId;
  final String? branchName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StaffEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.roleName,
    this.shopName,
    this.branchId,
    this.branchName,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        email,
        phone,
        roleName,
        shopName,
        branchId,
        branchName,
        createdAt,
        updatedAt,
      ];
}
