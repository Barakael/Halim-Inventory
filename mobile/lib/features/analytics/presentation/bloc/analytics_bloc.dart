import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/analytics_entity.dart';
import '../../domain/repositories/analytics_repository.dart';

// Events
abstract class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();
  @override
  List<Object?> get props => [];
}

class AnalyticsFetchRequested extends AnalyticsEvent {
  const AnalyticsFetchRequested();
}

// States
abstract class AnalyticsState extends Equatable {
  const AnalyticsState();
  @override
  List<Object?> get props => [];
}

class AnalyticsInitial extends AnalyticsState { const AnalyticsInitial(); }
class AnalyticsLoading extends AnalyticsState { const AnalyticsLoading(); }

class AnalyticsLoaded extends AnalyticsState {
  final AnalyticsEntity analytics;
  const AnalyticsLoaded(this.analytics);
  @override
  List<Object?> get props => [analytics];
}

class AnalyticsError extends AnalyticsState {
  final String message;
  const AnalyticsError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  final AnalyticsRepository analyticsRepository;

  AnalyticsBloc({required this.analyticsRepository})
      : super(const AnalyticsInitial()) {
    on<AnalyticsFetchRequested>(_onFetch);
  }

  Future<void> _onFetch(
    AnalyticsFetchRequested event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(const AnalyticsLoading());
    final result = await analyticsRepository.getAnalytics();
    result.fold(
      (f) => emit(AnalyticsError(f.message)),
      (analytics) => emit(AnalyticsLoaded(analytics)),
    );
  }
}
