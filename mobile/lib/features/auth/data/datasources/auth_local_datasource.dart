import 'dart:convert';
import '../../../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class AuthLocalDataSource {
  final SecureStorage secureStorage;

  const AuthLocalDataSource({required this.secureStorage});

  Future<void> saveToken(String token) => secureStorage.saveToken(token);

  Future<String?> getToken() => secureStorage.getToken();

  Future<void> saveUser(UserModel user) =>
      secureStorage.saveUser(jsonEncode(user.toJson()));

  Future<UserModel?> getUser() async {
    final raw = await secureStorage.getUser();
    if (raw == null) return null;
    return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clearSession() => secureStorage.clearAll();
}
