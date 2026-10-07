import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/shop_repository.dart';
import 'shop_event.dart';
import 'shop_state.dart';

class ShopBloc extends Bloc<ShopEvent, ShopState> {
  final ShopRepository _repository;

  ShopBloc(this._repository) : super(const ShopInitial()) {
    on<ShopRequested>(_onShopRequested);
    on<ShopCreateRequested>(_onShopCreateRequested);
    on<ShopUpdateRequested>(_onShopUpdateRequested);
    on<ShopDeleteRequested>(_onShopDeleteRequested);
    on<ShopDetailRequested>(_onShopDetailRequested);
  }

  Future<void> _onShopRequested(
    ShopRequested event,
    Emitter<ShopState> emit,
  ) async {
    emit(const ShopLoading());
    try {
      final shops = await _repository.getShops();
      emit(ShopLoaded(shops));
    } catch (e) {
      emit(ShopError(e.toString())); 
    }
  }

  Future<void> _onShopCreateRequested(
    ShopCreateRequested event,
    Emitter<ShopState> emit,
  ) async {
    try {
      final newShop = await _repository.createShop(
        name: event.name,
        address: event.address,
        phone: event.phone,
        email: event.email,
        taxRate: event.taxRate,
        currency: event.currency,
        ownerName: event.ownerName,
        ownerEmail: event.ownerEmail,
        ownerPassword: event.ownerPassword,
      );
      emit(ShopCreated(newShop));
      // Refresh the list
      add(const ShopRequested());
    } catch (e) {
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onShopUpdateRequested(
    ShopUpdateRequested event,
    Emitter<ShopState> emit,
  ) async {
    try {
      final updatedShop = await _repository.updateShop(
        id: event.id,
        name: event.name,
        address: event.address,
        phone: event.phone,
        email: event.email,
        currency: event.currency,
        status: event.status,
      );
      emit(ShopUpdated(updatedShop));
      // Refresh the list
      add(const ShopRequested());
    } catch (e) {
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onShopDeleteRequested(
    ShopDeleteRequested event,
    Emitter<ShopState> emit,
  ) async {
    try {
      await _repository.deleteShop(event.id);
      emit(const ShopDeleted());
      // Refresh the list
      add(const ShopRequested());
    } catch (e) {
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onShopDetailRequested(
    ShopDetailRequested event,
    Emitter<ShopState> emit,
  ) async {
    try {
      final shop = await _repository.getShop(event.id);
      emit(ShopDetailLoaded(shop));
    } catch (e) {
      emit(ShopError(e.toString()));
    }
  }
}
