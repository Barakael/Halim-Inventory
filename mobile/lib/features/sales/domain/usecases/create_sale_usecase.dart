import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/sale_entity.dart';
import '../repositories/sales_repository.dart';

class CreateSaleUseCase {
  final SalesRepository repository;
  const CreateSaleUseCase(this.repository);

  Future<Either<Failure, SaleEntity>> call(Map<String, dynamic> saleData) =>
      repository.createSale(saleData);
}
