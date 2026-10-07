import 'package:bloc/bloc.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import 'transactions_event.dart';
import 'transactions_state.dart';

class TransactionsBloc extends Bloc<TransactionsEvent, TransactionsState> {
  final GetTransactionsUseCase getTransactionsUseCase;

  TransactionsBloc({required this.getTransactionsUseCase})
      : super(TransactionsInitial()) {
    on<TransactionsFetchRequested>(_onTransactionsFetchRequested);
  }

  Future<void> _onTransactionsFetchRequested(
    TransactionsFetchRequested event,
    Emitter<TransactionsState> emit,
  ) async {
    emit(TransactionsLoading());
    try {
      final transactions = await getTransactionsUseCase.call(date: event.date);
      emit(TransactionsLoaded(transactions: transactions));
    } catch (e) {
      emit(TransactionsError(message: e.toString()));
    }
  }
}
