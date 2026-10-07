part of 'owner_settings_bloc.dart';

abstract class OwnerSettingsEvent extends Equatable {
  const OwnerSettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadShopData extends OwnerSettingsEvent {}

class UpdateShopInfo extends OwnerSettingsEvent {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String currency;

  const UpdateShopInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.currency,
  });

  @override
  List<Object?> get props => [name, address, phone, email, currency];
}

class LoadBranches extends OwnerSettingsEvent {}

class CreateBranch extends OwnerSettingsEvent {
  final String name;
  final String address;
  final String? phone;

  const CreateBranch({
    required this.name,
    required this.address,
    this.phone,
  });

  @override
  List<Object?> get props => [name, address, phone];
}

class DeleteBranch extends OwnerSettingsEvent {
  final int id;

  const DeleteBranch(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadSubscription extends OwnerSettingsEvent {}
