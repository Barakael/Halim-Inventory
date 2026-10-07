import '../entities/staff_entity.dart';

abstract class StaffRepository {
  Future<List<StaffEntity>> getStaff();
  Future<StaffEntity> createStaff({
    required String name,
    required String email,
    required String password,
    required int branchId,
  });
  Future<StaffEntity> updateStaff({                           
    required int id,
    required String name,
    required String email,
    String? password,
    int? branchId,
  });
  Future<void> deleteStaff(int id);
}
