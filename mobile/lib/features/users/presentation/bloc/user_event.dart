import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

class UsersFetchRequested extends UserEvent {
  const UsersFetchRequested();
}

class UserCreateRequested extends UserEvent {
  final Map<String, dynamic> data;
  const UserCreateRequested(this.data);

  @override
  List<Object?> get props => [data];
}

class UserUpdateRequested extends UserEvent {
  final String id;
  final Map<String, dynamic> data;
  const UserUpdateRequested(this.id, this.data);

  @override
  List<Object?> get props => [id, data];
}

class UserDeleteRequested extends UserEvent {
  final String id;
  const UserDeleteRequested(this.id);

  @override
  List<Object?> get props => [id];
}
