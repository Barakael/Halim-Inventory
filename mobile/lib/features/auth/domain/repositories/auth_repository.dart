import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserEntity>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    String? companyId,
    String? roleId,
    String? roleName,
  });

  Future<Either<Failure, void>> verifyPhone({
    required String phone,
    required String token,
  });

  Future<Either<Failure, void>> resendVerification({required String phone});

  Future<Either<Failure, UserEntity>> getMe();

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Returns cached user if available (used on app startup).
  Future<UserEntity?> getCachedUser();
}
