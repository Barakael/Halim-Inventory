import 'package:get_it/get_it.dart';

import '../../../core/network/api_client.dart';
import '../data/datasources/transactions_remote_datasource.dart';
import '../data/repositories/transactions_repository_impl.dart';
import '../domain/repositories/transactions_repository.dart';
import '../domain/usecases/get_transactions_usecase.dart';
import '../presentation/bloc/transactions_bloc.dart';

class TransactionsInjection {
  static void init() {
    final GetIt getIt = GetIt.instance;

    getIt.registerLazySingleton<TransactionsRemoteDataSource>(
      () => TransactionsRemoteDataSourceImpl(
        apiClient: getIt<ApiClient>(),
      ),
    );

    getIt.registerLazySingleton<TransactionsRepository>(
      () => TransactionsRepositoryImpl(
        remoteDataSource: getIt<TransactionsRemoteDataSource>(),
      ),
    );

    getIt.registerLazySingleton<GetTransactionsUseCase>(
      () => GetTransactionsUseCase(
        repository: getIt<TransactionsRepository>(),
      ),
    );

    getIt.registerFactory<TransactionsBloc>(
      () => TransactionsBloc(
        getTransactionsUseCase: getIt<GetTransactionsUseCase>(),
      ),
    );
  }
}
