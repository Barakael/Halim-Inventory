import '../../domain/entities/shop_entity.dart';

class ShopModel extends ShopEntity {
  const ShopModel({
    required super.id,
    required super.name,
    super.address = '',
    super.phone = '',
    super.email = '',
    super.taxRate = 0.0,
    super.currency = 'TZS',
    super.tin = '',
    super.vrn = '',
    super.mobile = '',
    super.location = '',
    super.taxOffice = '',
    super.serialPrefix = 'DEM',
    super.status = 'active',
    super.manager,
    super.ownerName,
    super.ownerEmail,
    super.branchesCount,
    super.staffCount,
    super.createdAt,
    super.updatedAt,
  });

  /// Laravel/API snake_case shop payload (e.g. nested under login `user.shop`).
  factory ShopModel.fromApi(Map<String, dynamic> json) {
    // Some endpoints wrap the shop: { shop: {...} } or { data: {...} }.
    Map<String, dynamic> raw = json;
    final nestedShop = json['shop'];
    if (nestedShop is Map<String, dynamic>) {
      raw = nestedShop;
    } else if (json['data'] is Map<String, dynamic> && json['id'] == null) {
      raw = json['data'] as Map<String, dynamic>;
    }

    final idVal = raw['id'];
    final id = idVal is int
        ? idVal
        : idVal is num
            ? idVal.toInt()
            : int.tryParse(idVal?.toString() ?? '') ?? 0;

    final taxRaw = raw['tax_rate'] ?? raw['taxRate'];
    final taxRate = taxRaw is num
        ? taxRaw.toDouble()
        : double.tryParse(taxRaw?.toString() ?? '') ?? 18.0;

    String? ownerName;
    String? ownerEmail;
    final ownerRaw = raw['owner'];
    if (ownerRaw is Map) {
      ownerName = ownerRaw['name']?.toString();
      ownerEmail = ownerRaw['email']?.toString();
    } else {
      ownerName = raw['owner_name']?.toString() ?? raw['manager_name']?.toString();
      ownerEmail = raw['owner_email']?.toString();
    }

    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '');
    }

    return ShopModel(
      id: id,
      name: raw['name']?.toString() ?? '',
      address: raw['address']?.toString() ?? '',
      phone: raw['phone']?.toString() ?? '',
      email: raw['email']?.toString() ?? '',
      taxRate: taxRate,
      currency: raw['currency']?.toString() ?? 'TZS',
      tin: raw['tin']?.toString() ?? '',
      vrn: raw['vrn']?.toString() ?? '',
      mobile: raw['mobile']?.toString() ?? '',
      location: raw['location']?.toString() ?? '',
      taxOffice: raw['tax_office']?.toString() ?? raw['taxOffice']?.toString() ?? '',
      serialPrefix:
          raw['serial_prefix']?.toString() ?? raw['serialPrefix']?.toString() ?? 'DEM',
      status: raw['status']?.toString() ?? 'active',
      manager: ownerName,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      branchesCount: asInt(raw['branches_count']),
      staffCount: asInt(raw['staff_count']),
      createdAt: raw['created_at'] != null
          ? DateTime.tryParse(raw['created_at'].toString())
          : null,
      updatedAt: raw['updated_at'] != null
          ? DateTime.tryParse(raw['updated_at'].toString())
          : null,
    );
  }

  factory ShopModel.fromJson(Map<String, dynamic> json) => ShopModel.fromApi(json);

  Map<String, dynamic> toApiJson() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'email': email,
        'tax_rate': taxRate,
        'currency': currency,
        'tin': tin,
        'vrn': vrn,
        'mobile': mobile,
        'location': location,
        'tax_office': taxOffice,
        'serial_prefix': serialPrefix,
        'status': status,
        'manager_name': manager,
        'owner_name': ownerName,
        'owner_email': ownerEmail,
        'branches_count': branchesCount,
        'staff_count': staffCount,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> toJson() => toApiJson();
}
