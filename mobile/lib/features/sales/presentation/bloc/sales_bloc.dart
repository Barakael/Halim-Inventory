import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_sales_usecase.dart';
import '../../domain/usecases/create_sale_usecase.dart';
import '../../domain/repositories/sales_repository.dart';
import 'sales_event.dart';
import 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final GetSalesUseCase getSalesUseCase;
  final CreateSaleUseCase createSaleUseCase;
  final SalesRepository salesRepository;

  SalesBloc({
    required this.getSalesUseCase,
    required this.createSaleUseCase,
    required this.salesRepository,
  }) : super(const SalesInitial()) {
    on<SalesFetchRequested>(_onFetch);
    on<SaleCreateRequested>(_onCreate);
    on<SaleDetailRequested>(_onDetail);
  }

  Future<void> _onFetch(
    SalesFetchRequested event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    final result = await getSalesUseCase(date: event.date);
    result.fold(
      (f) => emit(SalesError(f.message)),
      (sales) => emit(SalesLoaded(
        sales: sales,
        hasMore: false,
        currentPage: 1,
      )),
    );
  }

  Future<void> _onCreate(
    SaleCreateRequested event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    final result = await createSaleUseCase(event.saleData);
    result.fold(
      (f) => emit(SalesError(f.message)),
      (sale) => emit(SaleCreated(sale)),
    );
  }

  Future<void> _onDetail(
    SaleDetailRequested event,
    Emitter<SalesState> emit,
  ) async {
    emit(const SalesLoading());
    final result = await salesRepository.getSaleById(event.id);
    result.fold(
      (f) => emit(SalesError(f.message)),
      (sale) => emit(SaleDetailLoaded(sale)),
    );
  }
}
