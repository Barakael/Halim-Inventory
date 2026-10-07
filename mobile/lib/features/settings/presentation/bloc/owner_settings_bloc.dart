import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shops/domain/entities/shop_entity.dart';
import '../../domain/repositories/owner_settings_repository.dart';

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

class BranchesLoaded extends OwnerSettingsState {
  final List<dynamic> branches;

  const BranchesLoaded(this.branches);

  @override
  List<Object?> get props => [branches];
}

class SubscriptionLoaded extends OwnerSettingsState {
  final dynamic subscription;

  const SubscriptionLoaded(this.subscription);

  @override
  List<Object?> get props => [subscription];
}

class OwnerSettingsError extends OwnerSettingsState {
  final String message;

  const OwnerSettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

class OwnerSettingsBloc extends Bloc<OwnerSettingsEvent, OwnerSettingsState> {
  final OwnerSettingsRepository _repository;

  OwnerSettingsBloc(this._repository) : super(OwnerSettingsInitial()) {
    on<LoadShopData>((event, emit) async {
      emit(OwnerSettingsLoading());
      try {
        final shop = await _repository.getCurrentShop();
        if (shop != null) {
          emit(ShopDataLoaded(shop));
        } else {
          emit(OwnerSettingsError('No shop found'));
        }
      } catch (e) {
        emit(OwnerSettingsError(e.toString()));
      }
    });

    on<UpdateShopInfo>((event, emit) async {
      emit(OwnerSettingsLoading());
      try {
        // TODO: Implement actual shop update API call
        await Future.delayed(const Duration(seconds: 1));
        emit(OwnerSettingsError('Shop update not implemented yet'));
      } catch (e) {
        emit(OwnerSettingsError(e.toString()));
      }
    });

    on<LoadBranches>((event, emit) async {
      emit(OwnerSettingsLoading());
      try {
        final branches = await _repository.getBranches();
        emit(BranchesLoaded(branches));
      } catch (e) {
        emit(OwnerSettingsError(e.toString()));
      }
    });

    on<CreateBranch>((event, emit) async {
      emit(OwnerSettingsLoading());
      try {
        final branch = await _repository.createBranch(
          name: event.name,
          address: event.address,
          phone: event.phone,
        );
        // Reload branches after creation
        add(LoadBranches());
      } catch (e) {
        emit(OwnerSettingsError(e.toString()));
      }
    });

    on<DeleteBranch>((event, emit) async {
      emit(OwnerSettingsLoading());
      try {
        await _repository.deleteBranch(event.id);
        // Reload branches after deletion
        add(LoadBranches());
      } catch (e) {
        emit(OwnerSettingsError(e.toString()));
      }
    });

    on<LoadSubscription>((event, emit) async {
      emit(OwnerSettingsLoading());
      try {
        final subscription = await _repository.getSubscription();
        emit(SubscriptionLoaded(subscription));
      } catch (e) {
        emit(OwnerSettingsError(e.toString()));
      }
    });
  }
}
