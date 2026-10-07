import 'package:equatable/equatable.dart';

abstract class ShopEvent extends Equatable {
  const ShopEvent();

  @override
  List<Object?> get props => [];
}

class ShopRequested extends ShopEvent {
  const ShopRequested();
}

class ShopCreateRequested extends ShopEvent {
  final String name;
  final String address;
  final String phone;
  final String email;
  final double taxRate;
  final String currency;
  final String ownerName;
  final String ownerEmail;
  final String ownerPassword;

  const ShopCreateRequested({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    this.taxRate = 0.0,
    this.currency = 'TZS',
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPassword,
  });

  @override
  List<Object?> get props => [name, address, phone, email, taxRate, currency, ownerName, ownerEmail, ownerPassword];
}

class ShopUpdateRequested extends ShopEvent {
  final int id;
  final String? name;
  final String? address;
  final String? phone;
  final String? email;
  final String? currency;
  final String? status;

  const ShopUpdateRequested({
    required this.id,
    this.name,
    this.address,
    this.phone,
    this.email,
    this.currency,
    this.status,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        phone,
        email,
        currency,
        status,
      ];
}

class ShopDeleteRequested extends ShopEvent {
  final int id;

  const ShopDeleteRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class ShopDetailRequested extends ShopEvent {
  final int id;

  const ShopDetailRequested(this.id);

  @override
  List<Object?> get props => [id];
}
