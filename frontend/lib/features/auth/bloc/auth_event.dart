import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginRequested(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class AuthSignupRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthSignupRequested(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class AuthAuth0LoginRequested extends AuthEvent {
  final String token;
  const AuthAuth0LoginRequested(this.token);

  @override
  List<Object?> get props => [token];
}

class AuthLogoutRequested extends AuthEvent {}
