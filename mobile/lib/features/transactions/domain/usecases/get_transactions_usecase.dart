import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

class GetTransactionsUseCase {
  final TransactionsRepository repository;

  GetTransactionsUseCase({required this.repository});

  Future<List<TransactionEntity>> call({String? date}) async {
    return await repository.getTransactions(date: date);
  }
}
