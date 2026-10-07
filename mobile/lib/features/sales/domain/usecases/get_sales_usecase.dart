import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/sale_entity.dart';
import '../repositories/sales_repository.dart';

class GetSalesUseCase {
  final SalesRepository repository;
  const GetSalesUseCase(this.repository);

  Future<Either<Failure, List<SaleEntity>>> call({String? date}) =>
      repository.getSales(date: date);
}
