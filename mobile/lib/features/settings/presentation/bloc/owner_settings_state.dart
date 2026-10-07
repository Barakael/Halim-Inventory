part of 'owner_settings_bloc.dart';

abstract class OwnerSettingsState extends Equatable {
  const OwnerSettingsState();

  @override
  List<Object?> get props => [];
}

class OwnerSettingsInitial extends OwnerSettingsState {}

class OwnerSettingsLoading extends OwnerSettingsState {}

class ShopDataLoaded extends OwnerSettingsState {
  final ShopEntity shop;

  const ShopDataLoaded(this.shop);

  @override
  List<Object?> get props => [shop];
}

// TODO: Implement BranchEntity and SubscriptionEntity when needed
// class BranchesLoaded extends OwnerSettingsState {
//   final List<BranchEntity> branches;
//   const BranchesLoaded(this.branches);
//   @override
//   List<Object?> get props => [branches];
// }

// class SubscriptionLoaded extends OwnerSettingsState {
//   final SubscriptionEntity subscription;
//   const SubscriptionLoaded(this.subscription);
//   @override
//   List<Object?> get props => [subscription];
// }

class OwnerSettingsSuccess extends OwnerSettingsState {
  final String message;

  const OwnerSettingsSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class OwnerSettingsError extends OwnerSettingsState {
  final String message;

  const OwnerSettingsError(this.message);

  @override
  List<Object?> get props => [message];
}
