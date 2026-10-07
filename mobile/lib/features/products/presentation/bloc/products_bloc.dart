import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/products_repository.dart';
import '../../domain/usecases/get_products_usecase.dart';

// Events
abstract class ProductsEvent extends Equatable {
  const ProductsEvent();
  @override
  List<Object?> get props => [];
}

class ProductsFetchRequested extends ProductsEvent {
  final String? search;
  const ProductsFetchRequested({this.search});
}

class ProductCreateRequested extends ProductsEvent {
  final Map<String, dynamic> data;
  const ProductCreateRequested(this.data);
}

class ProductUpdateRequested extends ProductsEvent {
  final String id;
  final Map<String, dynamic> data;
  const ProductUpdateRequested(this.id, this.data);
}

class ProductDeleteRequested extends ProductsEvent {
  final String id;
  const ProductDeleteRequested(this.id);
}

// States
abstract class ProductsState extends Equatable {
  const ProductsState();
  @override
  List<Object?> get props => [];
}

class ProductsInitial extends ProductsState { const ProductsInitial(); }
class ProductsLoading extends ProductsState { const ProductsLoading(); }

class ProductsLoaded extends ProductsState {
  final List<ProductEntity> products;
  const ProductsLoaded(this.products);
  @override
  List<Object?> get props => [products];
}

class ProductActionSuccess extends ProductsState {
  final String message;
  const ProductActionSuccess(this.message);
}

class ProductsError extends ProductsState {
  final String message;
  const ProductsError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final GetProductsUseCase getProductsUseCase;
  final ProductsRepository productsRepository;

  ProductsBloc({
    required this.getProductsUseCase,
    required this.productsRepository,
  }) : super(const ProductsInitial()) {
    on<ProductsFetchRequested>(_onFetch);
    on<ProductCreateRequested>(_onCreate);
    on<ProductUpdateRequested>(_onUpdate);
    on<ProductDeleteRequested>(_onDelete);
  }

  Future<void> _onFetch(
    ProductsFetchRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    final result = await getProductsUseCase(search: event.search);
    result.fold(
      (f) => emit(ProductsError(f.message)),
      (products) => emit(ProductsLoaded(products)),
    );
  }

  Future<void> _onCreate(
    ProductCreateRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    final result = await productsRepository.createProduct(event.data);
    result.fold(
      (f) => emit(ProductsError(f.message)),
      (_) => emit(const ProductActionSuccess('Product created')),
    );
  }

  Future<void> _onUpdate(
    ProductUpdateRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    final result =
        await productsRepository.updateProduct(event.id, event.data);
    result.fold(
      (f) => emit(ProductsError(f.message)),
      (_) => emit(const ProductActionSuccess('Product updated')),
    );
  }

  Future<void> _onDelete(
    ProductDeleteRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    final result = await productsRepository.deleteProduct(event.id);
    result.fold(
      (f) => emit(ProductsError(f.message)),
      (_) => emit(const ProductActionSuccess('Product deleted')),
    );
  }
}
