import 'package:equatable/equatable.dart';
import '../../domain/entities/shop_entity.dart';

abstract class ShopState extends Equatable {
  const ShopState();

  @override
  List<Object?> get props => [];
}

class ShopInitial extends ShopState {
  const ShopInitial();
}

class ShopLoading extends ShopState {
  const ShopLoading();
}

class ShopLoaded extends ShopState {
  final List<ShopEntity> shops;

  const ShopLoaded(this.shops);

  @override
  List<Object?> get props => [shops];
}

class ShopCreated extends ShopState {
  final ShopEntity shop;

  const ShopCreated(this.shop);

  @override
  List<Object?> get props => [shop];
}

class ShopUpdated extends ShopState {
  final ShopEntity shop;

  const ShopUpdated(this.shop);

  @override
  List<Object?> get props => [shop];
}

class ShopDeleted extends ShopState {
  const ShopDeleted();
}

class ShopDetailLoaded extends ShopState {
  final ShopEntity shop;

  const ShopDetailLoaded(this.shop);

  @override
  List<Object?> get props => [shop];
}

class ShopError extends ShopState {
  final String message;

  const ShopError(this.message);

  @override
  List<Object?> get props => [message];
}
