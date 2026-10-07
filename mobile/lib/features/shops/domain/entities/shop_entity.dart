import 'package:equatable/equatable.dart';

class ShopEntity extends Equatable {
  final int id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final double taxRate;
  final String currency;
  final String tin;
  final String vrn;
  final String mobile;
  final String location;
  final String taxOffice;
  final String serialPrefix;
  final String status;
  final String? manager;
  final String? ownerName;
  final String? ownerEmail;
  final int? branchesCount;
  final int? staffCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ShopEntity({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.taxRate = 0.0,
    this.currency = 'TZS',
    this.tin = '',
    this.vrn = '',
    this.mobile = '',
    this.location = '',
    this.taxOffice = '',
    this.serialPrefix = 'DEM',
    this.status = 'active',
    this.manager,
    this.ownerName,
    this.ownerEmail,
    this.branchesCount,
    this.staffCount,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        phone,
        email,
        taxRate,
        currency,
        tin,
        vrn,
        mobile,
        location,
        taxOffice,
        serialPrefix,
        status,
        manager,
        ownerName,
        ownerEmail,
        branchesCount,
        staffCount,
        createdAt,
        updatedAt,
      ];
}
