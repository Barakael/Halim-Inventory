import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/analytics_entity.dart';

abstract class AnalyticsRepository {
  Future<Either<Failure, AnalyticsEntity>> getAnalytics({String? date});
}
