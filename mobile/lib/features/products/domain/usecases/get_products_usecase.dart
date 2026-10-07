import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/product_entity.dart';
import '../repositories/products_repository.dart';

class GetProductsUseCase {
  final ProductsRepository repository;
  const GetProductsUseCase(this.repository);

  Future<Either<Failure, List<ProductEntity>>> call({String? search}) =>
      repository.getProducts(search: search);
}
