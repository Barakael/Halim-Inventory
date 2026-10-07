import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../repositories/auth_repository.dart';

class VerifyPhoneUseCase {
  final AuthRepository repository;

  const VerifyPhoneUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String phone,
    required String token,
  }) {
    return repository.verifyPhone(phone: phone, token: token);
  }
}
