import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/user_repository.dart';
import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository repository;

  UserBloc(this.repository) : super(UserInitial()) {
    on<UsersFetchRequested>(_onUsersFetchRequested);
    on<UserCreateRequested>(_onUserCreateRequested);
    on<UserUpdateRequested>(_onUserUpdateRequested);
    on<UserDeleteRequested>(_onUserDeleteRequested);
  }

  Future<void> _onUsersFetchRequested(
    UsersFetchRequested event,
    Emitter<UserState> emit,
  ) async {
    emit(UsersLoading());
    try {
      final users = await repository.getUsers();
      emit(UsersLoaded(users));
    } catch (error) {
      emit(UserError(error.toString()));
    }
  }

  Future<void> _onUserCreateRequested(
    UserCreateRequested event,
    Emitter<UserState> emit,
  ) async {
    try {
      await repository.createUser(event.data);
      emit(UserActionSuccess('User created successfully'));
      add(UsersFetchRequested());
    } catch (error) {
      emit(UserError(error.toString()));
    }
  }

  Future<void> _onUserUpdateRequested(
    UserUpdateRequested event,
    Emitter<UserState> emit,
  ) async {
    try {
      await repository.updateUser(event.id, event.data);
      emit(UserActionSuccess('User updated successfully'));
      add(UsersFetchRequested());
    } catch (error) {
      emit(UserError(error.toString()));
    }
  }

  Future<void> _onUserDeleteRequested(
    UserDeleteRequested event,
    Emitter<UserState> emit,
  ) async {
    try {
      await repository.deleteUser(event.id);
      emit(UserActionSuccess('User deleted successfully'));
      add(UsersFetchRequested());
    } catch (error) {
      emit(UserError(error.toString()));
    }
  }
}
