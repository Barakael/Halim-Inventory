import '../entities/user_entity.dart';

abstract class UserRepository {
  Future<List<UserEntity>> getUsers();
  Future<UserEntity> createUser(Map<String, dynamic> userData);
  Future<UserEntity> updateUser(String id, Map<String, dynamic> userData);
  Future<void> deleteUser(String id);
}
