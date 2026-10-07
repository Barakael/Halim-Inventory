import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/notification_entity.dart';
import '../../data/datasources/notifications_remote_datasource.dart';

// Events
abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();
  @override
  List<Object?> get props => [];
}

class NotificationsFetchRequested extends NotificationsEvent {
  const NotificationsFetchRequested();
}

class NotificationMarkReadRequested extends NotificationsEvent {
  final String id;
  const NotificationMarkReadRequested(this.id);
  @override
  List<Object?> get props => [id];
}

class NotificationsMarkAllReadRequested extends NotificationsEvent {
  const NotificationsMarkAllReadRequested();
}

// States
abstract class NotificationsState extends Equatable {
  const NotificationsState();
  @override
  List<Object?> get props => [];
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  final List<NotificationEntity> notifications;
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  const NotificationsLoaded(this.notifications);

  @override
  List<Object?> get props => [notifications];
}

class NotificationsError extends NotificationsState {
  final String message;
  const NotificationsError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationsRemoteDataSource dataSource;

  NotificationsBloc({required this.dataSource})
      : super(const NotificationsInitial()) {
    on<NotificationsFetchRequested>(_onFetch);
    on<NotificationMarkReadRequested>(_onMarkRead);
    on<NotificationsMarkAllReadRequested>(_onMarkAllRead);
  }

  Future<void> _onFetch(
    NotificationsFetchRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(const NotificationsLoading());
    try {
      final models = await dataSource.getNotifications();
      emit(NotificationsLoaded(
          models.map((m) => m.toEntity()).toList()));
    } on ServerException catch (e) {
      emit(NotificationsError(e.message));
    } on NetworkException catch (e) {
      emit(NotificationsError(e.message));
    } catch (e) {
      emit(NotificationsError(e.toString()));
    }
  }

  Future<void> _onMarkRead(
    NotificationMarkReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await dataSource.markAsRead(event.id);
      add(const NotificationsFetchRequested());
    } catch (_) {}
  }

  Future<void> _onMarkAllRead(
    NotificationsMarkAllReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await dataSource.markAllAsRead();
      add(const NotificationsFetchRequested());
    } catch (_) {}
  }
}
