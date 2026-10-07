import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/product_entity.dart';

abstract class ProductsRepository {
  Future<Either<Failure, List<ProductEntity>>> getProducts({
    int page = 1,
    int limit = 50,
    String? search,
  });
  Future<Either<Failure, ProductEntity>> getProductById(String id);
  Future<Either<Failure, ProductEntity>> createProduct(Map<String, dynamic> data);
  Future<Either<Failure, ProductEntity>> updateProduct(String id, Map<String, dynamic> data);
  Future<Either<Failure, void>> deleteProduct(String id);
}
