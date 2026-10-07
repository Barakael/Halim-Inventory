import 'package:equatable/equatable.dart';

abstract class SalesEvent extends Equatable {
  const SalesEvent();
  @override
  List<Object?> get props => [];
}

class SalesFetchRequested extends SalesEvent {
  final String? date;

  const SalesFetchRequested({this.date});

  @override
  List<Object?> get props => [date];
}

class SaleCreateRequested extends SalesEvent {
  final Map<String, dynamic> saleData;
  const SaleCreateRequested(this.saleData);
  @override
  List<Object?> get props => [saleData];
}

class SaleDetailRequested extends SalesEvent {
  final String id;
  const SaleDetailRequested(this.id);
  @override
  List<Object?> get props => [id];
}
