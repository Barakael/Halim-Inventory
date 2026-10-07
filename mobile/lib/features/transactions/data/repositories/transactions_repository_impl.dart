import '../datasources/transactions_remote_datasource.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transactions_repository.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  final TransactionsRemoteDataSource remoteDataSource;

  TransactionsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<TransactionEntity>> getTransactions({String? date}) async {
    try {
      final transactionModels = await remoteDataSource.getTransactions(date: date);
      return transactionModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw Exception('Failed to load transactions: $e');
    }
  }
}
