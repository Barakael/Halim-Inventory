import 'package:equatable/equatable.dart';
import '../../domain/entities/staff_entity.dart';

abstract class StaffState extends Equatable {
  const StaffState();

  @override
  List<Object?> get props => [];
}

class StaffInitial extends StaffState {
  const StaffInitial();
}

class StaffLoading extends StaffState {
  const StaffLoading();
}

class StaffLoaded extends StaffState {
  final List<StaffEntity> staff;

  const StaffLoaded(this.staff);

  @override
  List<Object?> get props => [staff];
}

class StaffCreated extends StaffState {
  final StaffEntity staff;

  const StaffCreated(this.staff);

  @override
  List<Object?> get props => [staff];
}

class StaffUpdated extends StaffState {
  final StaffEntity staff;

  const StaffUpdated(this.staff);

  @override
  List<Object?> get props => [staff];
}

class StaffDeleted extends StaffState {
  const StaffDeleted();
}

class StaffError extends StaffState {
  final String message;

  const StaffError(this.message);

  @override
  List<Object?> get props => [message];
}
