import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/verify_phone_usecase.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/shop_profile_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final VerifyPhoneUseCase verifyPhoneUseCase;
  final LogoutUseCase logoutUseCase;
  final AuthRepository authRepository;
  final ShopProfileService shopProfileService;

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.verifyPhoneUseCase,
    required this.logoutUseCase,
    required this.authRepository,
    required this.shopProfileService,
  }) : super(const AuthInitial()) {
    on<AuthCheckStatusRequested>(_onCheckStatus);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthVerifyPhoneRequested>(_onVerifyPhone);
    on<AuthResendVerificationRequested>(_onResendVerification);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthChangePasswordRequested>(_onChangePassword);
  }

  Future<void> _onCheckStatus(
    AuthCheckStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = await authRepository.getCachedUser();
    if (user != null) {
      emit(AuthAuthenticated(user: user));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await loginUseCase(
      username: event.username,
      password: event.password,
    );
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (user) {
        shopProfileService.resolveShop(fromAuth: user.shop);
        emit(AuthAuthenticated(user: user));
      },
    );
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await registerUseCase(
      firstName: event.firstName,
      lastName: event.lastName,
      email: event.email,
      phone: event.phone,
      password: event.password,
      companyId: event.companyId,
      roleId: event.roleId,
      roleName: event.roleName,
    );
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (user) =>
          emit(AuthPhoneVerificationRequired(phone: user.phone ?? event.phone)),
    );
  }

  Future<void> _onVerifyPhone(
    AuthVerifyPhoneRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await verifyPhoneUseCase(
      phone: event.phone,
      token: event.token,
    );
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (_) => emit(const AuthPhoneVerified()),
    );
  }

  Future<void> _onResendVerification(
    AuthResendVerificationRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result =
        await authRepository.resendVerification(phone: event.phone);
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (_) {},
    );
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await logoutUseCase();
    shopProfileService.clear();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onChangePassword(
    AuthChangePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await authRepository.changePassword(
      currentPassword: event.currentPassword,
      newPassword: event.newPassword,
    );
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (_) => emit(const AuthPasswordChanged()),
    );
  }
}
