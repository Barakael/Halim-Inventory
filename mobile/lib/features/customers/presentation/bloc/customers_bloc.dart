import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customers_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class CustomersEvent extends Equatable {
  const CustomersEvent();
  @override
  List<Object?> get props => [];
}

class CustomersFetchRequested extends CustomersEvent {
  final String? search;
  final bool topCustomers;
  const CustomersFetchRequested({this.search, this.topCustomers = false});
}

class CustomerCreateRequested extends CustomersEvent {
  final Map<String, dynamic> data;
  const CustomerCreateRequested(this.data);
}

class CustomerUpdateRequested extends CustomersEvent {
  final String id;
  final Map<String, dynamic> data;
  const CustomerUpdateRequested(this.id, this.data);
}

class CustomerDeleteRequested extends CustomersEvent {
  final String id;
  const CustomerDeleteRequested(this.id);
}

class CustomerLoyaltyRefreshRequested extends CustomersEvent {
  final String id;
  const CustomerLoyaltyRefreshRequested(this.id);
}

class DebtsFetchRequested extends CustomersEvent {
  final String? status;
  const DebtsFetchRequested({this.status});
}

class DebtSummaryFetchRequested extends CustomersEvent {
  const DebtSummaryFetchRequested();
}

class DebtCreateRequested extends CustomersEvent {
  final Map<String, dynamic> data;
  const DebtCreateRequested(this.data);
}

class DebtPaymentRequested extends CustomersEvent {
  final String debtId;
  final double amount;
  final String? note;
  const DebtPaymentRequested({
    required this.debtId,
    required this.amount,
    this.note,
  });
}

// ── States ────────────────────────────────────────────────────────────────────

abstract class CustomersState extends Equatable {
  const CustomersState();
  @override
  List<Object?> get props => [];
}

class CustomersInitial extends CustomersState {
  const CustomersInitial();
}

class CustomersLoading extends CustomersState {
  const CustomersLoading();
}

class CustomersLoaded extends CustomersState {
  final List<CustomerEntity> customers;
  final List<CustomerDebtEntity> debts;
  final DebtSummaryEntity? summary;

  const CustomersLoaded({
    required this.customers,
    this.debts = const [],
    this.summary,
  });

  CustomersLoaded copyWith({
    List<CustomerEntity>? customers,
    List<CustomerDebtEntity>? debts,
    DebtSummaryEntity? summary,
  }) =>
      CustomersLoaded(
        customers: customers ?? this.customers,
        debts: debts ?? this.debts,
        summary: summary ?? this.summary,
      );

  @override
  List<Object?> get props => [customers, debts, summary];
}

class CustomerActionSuccess extends CustomersState {
  final String message;
  const CustomerActionSuccess(this.message);
}

class CustomersError extends CustomersState {
  final String message;
  const CustomersError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Bloc ──────────────────────────────────────────────────────────────────────

class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  final CustomersRepository repository;

  List<CustomerEntity> _customers = [];
  List<CustomerDebtEntity> _debts = [];
  DebtSummaryEntity? _summary;

  CustomersBloc({required this.repository}) : super(const CustomersInitial()) {
    on<CustomersFetchRequested>(_onFetchCustomers);
    on<CustomerCreateRequested>(_onCreate);
    on<CustomerUpdateRequested>(_onUpdate);
    on<CustomerDeleteRequested>(_onDelete);
    on<CustomerLoyaltyRefreshRequested>(_onLoyalty);
    on<DebtsFetchRequested>(_onFetchDebts);
    on<DebtSummaryFetchRequested>(_onSummary);
    on<DebtCreateRequested>(_onCreateDebt);
    on<DebtPaymentRequested>(_onPayment);
  }

  Future<void> _onFetchCustomers(
    CustomersFetchRequested event,
    Emitter<CustomersState> emit,
  ) async {
    // Keep existing list visible while refreshing (avoids empty flash).
    if (_customers.isEmpty) {
      emit(const CustomersLoading());
    }
    try {
      _customers = await repository.getCustomers(
        search: event.search,
        topCustomers: event.topCustomers,
      );
      emit(CustomersLoaded(
        customers: _customers,
        debts: _debts,
        summary: _summary,
      ));
    } catch (e) {
      emit(CustomersError(e.toString().replaceFirst('Exception: ', '')));
      if (_customers.isNotEmpty || _debts.isNotEmpty) {
        emit(CustomersLoaded(
          customers: _customers,
          debts: _debts,
          summary: _summary,
        ));
      }
    }
  }

  Future<void> _onCreate(
    CustomerCreateRequested event,
    Emitter<CustomersState> emit,
  ) async {
    try {
      await repository.createCustomer(event.data);
      emit(const CustomerActionSuccess('Customer created'));
      // Reload without blanking the tab via CustomersLoading.
      _customers = await repository.getCustomers();
      emit(CustomersLoaded(
        customers: _customers,
        debts: _debts,
        summary: _summary,
      ));
    } catch (e) {
      emit(CustomersError(e.toString().replaceFirst('Exception: ', '')));
      if (_customers.isNotEmpty || _debts.isNotEmpty) {
        emit(CustomersLoaded(
          customers: _customers,
          debts: _debts,
          summary: _summary,
        ));
      }
    }
  }

  Future<void> _onUpdate(
    CustomerUpdateRequested event,
    Emitter<CustomersState> emit,
  ) async {
    try {
      await repository.updateCustomer(event.id, event.data);
      emit(const CustomerActionSuccess('Customer updated'));
      _customers = await repository.getCustomers();
      emit(CustomersLoaded(
        customers: _customers,
        debts: _debts,
        summary: _summary,
      ));
    } catch (e) {
      emit(CustomersError(e.toString().replaceFirst('Exception: ', '')));
      if (_customers.isNotEmpty || _debts.isNotEmpty) {
        emit(CustomersLoaded(
          customers: _customers,
          debts: _debts,
          summary: _summary,
        ));
      }
    }
  }

  Future<void> _onDelete(
    CustomerDeleteRequested event,
    Emitter<CustomersState> emit,
  ) async {
    try {
      await repository.deleteCustomer(event.id);
      emit(const CustomerActionSuccess('Customer deleted'));
      _customers = await repository.getCustomers();
      emit(CustomersLoaded(
        customers: _customers,
        debts: _debts,
        summary: _summary,
      ));
    } catch (e) {
      emit(CustomersError(e.toString().replaceFirst('Exception: ', '')));
      if (_customers.isNotEmpty || _debts.isNotEmpty) {
        emit(CustomersLoaded(
          customers: _customers,
          debts: _debts,
          summary: _summary,
        ));
      }
    }
  }

  Future<void> _onLoyalty(
    CustomerLoyaltyRefreshRequested event,
    Emitter<CustomersState> emit,
  ) async {
    try {
      await repository.refreshLoyalty(event.id);
      emit(const CustomerActionSuccess('Loyalty discount refreshed'));
      _customers = await repository.getCustomers();
      emit(CustomersLoaded(
        customers: _customers,
        debts: _debts,
        summary: _summary,
      ));
    } catch (e) {
      emit(CustomersError(e.toString().replaceFirst('Exception: ', '')));
      if (_customers.isNotEmpty || _debts.isNotEmpty) {
        emit(CustomersLoaded(
          customers: _customers,
          debts: _debts,
          summary: _summary,
        ));
      }
    }
  }

  Future<void> _onFetchDebts(
    DebtsFetchRequested event,
    Emitter<CustomersState> emit,
  ) async {
    try {
      _debts = await repository.getDebts(status: event.status);
      emit(CustomersLoaded(
        customers: _customers,
        debts: _debts,
        summary: _summary,
      ));
    } catch (e) {
      emit(CustomersError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onSummary(
    DebtSummaryFetchRequested event,
    Emitter<CustomersState> emit,
  ) async {
    try {
      _summary = await repository.getDebtSummary();
      emit(CustomersLoaded(
        customers: _customers,
        debts: _debts,
        summary: _summary,
      ));
    } catch (e) {
      emit(CustomersError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onCreateDebt(
    DebtCreateRequested event,
    Emitter<CustomersState> emit,
  ) async {
    try {
      await repository.createDebt(event.data);
      emit(const CustomerActionSuccess('Debt recorded'));
      add(const DebtsFetchRequested());
      add(const DebtSummaryFetchRequested());
      add(const CustomersFetchRequested());
    } catch (e) {
      emit(CustomersError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onPayment(
    DebtPaymentRequested event,
    Emitter<CustomersState> emit,
  ) async {
    try {
      await repository.recordPayment(
        event.debtId,
        amount: event.amount,
        note: event.note,
      );
      emit(const CustomerActionSuccess('Payment recorded'));
      add(const DebtsFetchRequested());
      add(const DebtSummaryFetchRequested());
      add(const CustomersFetchRequested());
    } catch (e) {
      emit(CustomersError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
