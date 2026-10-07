import 'package:equatable/equatable.dart';

abstract class TransactionsEvent extends Equatable {
  const TransactionsEvent();

  @override
  List<Object?> get props => [];
}

class TransactionsFetchRequested extends TransactionsEvent {
  final String? date;

  const TransactionsFetchRequested({this.date});

  @override
  List<Object?> get props => [date];
}
