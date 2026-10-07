import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/transaction_model.dart';

abstract class TransactionsRemoteDataSource {
  Future<List<TransactionModel>> getTransactions({String? date});
}

class TransactionsRemoteDataSourceImpl implements TransactionsRemoteDataSource {
  final ApiClient apiClient;

  const TransactionsRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<TransactionModel>> getTransactions({String? date}) async {
    try {
      final response = await apiClient.get<List<dynamic>>(
        endpoint: ApiEndpoints.sales,
        queryParameters: {
          if (date != null && date.isNotEmpty) 'date': date,
        },
        parser: (json) => json as List<dynamic>,
      );

      return response
          .map((e) =>
              TransactionModel.fromLaravelJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load transactions: $e');
    }
  }
}
