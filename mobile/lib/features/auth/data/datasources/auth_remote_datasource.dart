import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  });

  Future<AuthResponseModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    String? companyId,
    String? roleId,
    String? roleName,
  });

  Future<void> verifyPhone({required String phone, required String token});

  Future<void> resendVerification({required String phone});

  Future<UserModel> getMe();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
