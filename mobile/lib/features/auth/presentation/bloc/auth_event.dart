import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String? companyId;
  final String? roleId;
  final String? roleName;

  const AuthRegisterRequested({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    this.companyId,
    this.roleId,
    this.roleName,
  });

  @override
  List<Object?> get props =>
      [firstName, lastName, email, phone, password, companyId, roleId, roleName];
}

class AuthVerifyPhoneRequested extends AuthEvent {
  final String phone;
  final String token;

  const AuthVerifyPhoneRequested({required this.phone, required this.token});

  @override
  List<Object?> get props => [phone, token];
}

class AuthResendVerificationRequested extends AuthEvent {
  final String phone;

  const AuthResendVerificationRequested({required this.phone});

  @override
  List<Object?> get props => [phone];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthCheckStatusRequested extends AuthEvent {
  const AuthCheckStatusRequested();
}

class AuthChangePasswordRequested extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const AuthChangePasswordRequested({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword];
}
