import 'package:equatable/equatable.dart';

abstract class StaffEvent extends Equatable {
  const StaffEvent();

  @override
  List<Object?> get props => [];
}

class StaffRequested extends StaffEvent {
  const StaffRequested();
}

class StaffCreateRequested extends StaffEvent {
  final String name;
  final String email;
  final String password;
  final int branchId;

  const StaffCreateRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.branchId,
  });

  @override
  List<Object?> get props => [
        name,
        email,
        password,
        branchId,
      ];
}

class StaffUpdateRequested extends StaffEvent {
  final int id;
  final String name;
  final String email;
  final String? password;
  final int? branchId;

  const StaffUpdateRequested({
    required this.id,
    required this.name,
    required this.email,
    this.password,
    this.branchId,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        password,
        branchId,
      ];
}

class StaffDeleteRequested extends StaffEvent {
  final int id;

  const StaffDeleteRequested(this.id);

  @override
  List<Object?> get props => [id];
}
