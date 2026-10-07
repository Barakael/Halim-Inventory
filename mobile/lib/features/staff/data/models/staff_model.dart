import '../../domain/entities/staff_entity.dart';

class StaffModel extends StaffEntity {
  const StaffModel({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    required super.phone,
    super.roleName,
    super.shopName,
    super.branchId,
    super.branchName,
    super.createdAt,
    super.updatedAt,
  });

  /// Laravel `GET /staff` returns `{ id, name, email, branch_id, created_at, branch? }`.
  factory StaffModel.fromJson(Map<String, dynamic> json) =>
      StaffModel.fromApi(json);

  factory StaffModel.fromApi(Map<String, dynamic> json) {
    final fullName = json['name']?.toString() ?? '';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    String? branchName;
    final branch = json['branch'];
    if (branch is Map) {
      branchName = branch['name']?.toString();
    }
    branchName ??= json['branch_name']?.toString();

    return StaffModel(
      id: (json['id'] as num).toInt(),
      firstName: json['first_name']?.toString() ?? first,
      lastName: json['last_name']?.toString() ?? last,
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      roleName: json['role']?.toString() ?? json['role_name']?.toString() ?? 'cashier',
      shopName: json['shop_name']?.toString(),
      branchId: (json['branch_id'] as num?)?.toInt(),
      branchName: branchName,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': '$firstName $lastName'.trim(),
        'email': email,
        'phone': phone,
        'role': roleName,
        'branch_id': branchId,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
