import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/sale_entity.dart';

abstract class SalesRepository {
  Future<Either<Failure, List<SaleEntity>>> getSales({String? date});

  Future<Either<Failure, SaleEntity>> getSaleById(String id);

  Future<Either<Failure, SaleEntity>> createSale(
    Map<String, dynamic> saleData,
  );
}
