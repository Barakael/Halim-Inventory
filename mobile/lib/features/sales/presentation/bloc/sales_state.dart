import 'package:equatable/equatable.dart';
import '../../domain/entities/sale_entity.dart';

abstract class SalesState extends Equatable {
  const SalesState();
  @override
  List<Object?> get props => [];
}

class SalesInitial extends SalesState {
  const SalesInitial();
}

class SalesLoading extends SalesState {
  const SalesLoading();
}

class SalesLoaded extends SalesState {
  final List<SaleEntity> sales;
  final bool hasMore;
  final int currentPage;

  const SalesLoaded({
    required this.sales,
    this.hasMore = false,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [sales, hasMore, currentPage];
}

class SaleDetailLoaded extends SalesState {
  final SaleEntity sale;
  const SaleDetailLoaded(this.sale);
  @override
  List<Object?> get props => [sale];
}

class SaleCreated extends SalesState {
  final SaleEntity sale;
  const SaleCreated(this.sale);
  @override
  List<Object?> get props => [sale];
}

class SalesError extends SalesState {
  final String message;
  const SalesError(this.message);
  @override
  List<Object?> get props => [message];
}
