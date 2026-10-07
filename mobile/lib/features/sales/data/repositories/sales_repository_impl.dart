import 'package:fpdart/fpdart.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/sale_entity.dart';
import '../../domain/repositories/sales_repository.dart';
import '../datasources/sales_remote_datasource.dart';

class SalesRepositoryImpl implements SalesRepository {
  final SalesRemoteDataSource remoteDataSource;
  const SalesRepositoryImpl({required this.remoteDataSource});

  /// Normalizes mobile/legacy payloads to Laravel `POST /sales` body.
  static Map<String, dynamic> normalizeSalePayload(Map<String, dynamic> raw) {
    final rawItems = raw['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((e) {
      final m = e as Map<String, dynamic>;
      final pid = m['product_id'] ?? m['productId'];
      return {
        'product_id': pid is int ? pid : int.tryParse(pid.toString()) ?? pid,
        'quantity': m['quantity'],
        if (m['price'] != null) 'price': m['price'],
      };
    }).toList();

    final pm = (raw['payment_method'] ?? raw['paymentMethod'] ?? 'cash')
        .toString()
        .toLowerCase();
    final method = switch (pm) {
      'cash' => 'cash',
      'card' => 'card',
      'mobile' => 'mobile',
      'credit' => 'credit',
      _ when pm.contains('card') => 'card',
      _ when pm.contains('mobile') => 'mobile',
      _ when pm.contains('credit') => 'credit',
      _ => 'cash',
    };

    final shopCustomerId =
        raw['shop_customer_id'] ?? raw['shopCustomerId'];
    final amountTendered =
        raw['amount_tendered'] ?? raw['amountTendered'];

    return {
      'payment_method': method,
      'items': items,
      if (shopCustomerId != null)
        'shop_customer_id': shopCustomerId is int
            ? shopCustomerId
            : int.tryParse(shopCustomerId.toString()) ?? shopCustomerId,
      if (raw['customer_name'] != null || raw['customerName'] != null)
        'customer_name': raw['customer_name'] ?? raw['customerName'],
      if (raw['customer_phone'] != null || raw['customerPhone'] != null)
        'customer_phone': raw['customer_phone'] ?? raw['customerPhone'],
      if (raw['customer_address'] != null || raw['customerAddress'] != null)
        'customer_address': raw['customer_address'] ?? raw['customerAddress'],
      if (raw['customer_id_type'] != null || raw['customerIdType'] != null)
        'customer_id_type': raw['customer_id_type'] ?? raw['customerIdType'],
      if (raw['customer_id'] != null || raw['customerId'] != null)
        'customer_id': raw['customer_id'] ?? raw['customerId'],
      if (amountTendered != null) 'amount_tendered': amountTendered,
      if (raw['subtotal'] != null) 'subtotal': raw['subtotal'],
      if (raw['tax'] != null) 'tax': raw['tax'],
      if (raw['discount'] != null) 'discount': raw['discount'],
      if (raw['total'] != null) 'total': raw['total'],
      if (raw.containsKey('apply_loyalty_discount'))
        'apply_loyalty_discount': raw['apply_loyalty_discount'],
      if (raw['discount_mode'] != null) 'discount_mode': raw['discount_mode'],
      if (raw['manual_discount_percent'] != null)
        'manual_discount_percent': raw['manual_discount_percent'],
      if (raw['manual_discount_amount'] != null)
        'manual_discount_amount': raw['manual_discount_amount'],
      if (raw['debt_note'] != null) 'debt_note': raw['debt_note'],
      if (raw['debt_due_date'] != null) 'debt_due_date': raw['debt_due_date'],
      if (raw['client_sale_id'] != null || raw['clientSaleId'] != null)
        'client_sale_id': raw['client_sale_id'] ?? raw['clientSaleId'],
    };
  }

  @override
  Future<Either<Failure, List<SaleEntity>>> getSales({String? date}) async {
    try {
      final models = await remoteDataSource.getSales(date: date);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SaleEntity>> getSaleById(String id) async {
    try {
      final model = await remoteDataSource.getSaleById(id);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SaleEntity>> createSale(
    Map<String, dynamic> saleData,
  ) async {
    try {
      final model = await remoteDataSource.createSale(
        normalizeSalePayload(saleData),
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
