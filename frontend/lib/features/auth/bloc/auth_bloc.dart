import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import '../services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;

  AuthBloc({required this.authService}) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      final user = await authService.currentUser();
      emit(user != null ? AuthAuthenticated(user) : AuthUnauthenticated());
    });
    on<AuthLoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authService.signIn(event.email, event.password);
        emit(AuthAuthenticated(user));
      } on ApiException catch (e) {
        emit(AuthError(e.message));
      }
    });
    on<AuthSignupRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authService.signUp(event.email, event.password);
        emit(AuthAuthenticated(user));
      } on ApiException catch (e) {
        emit(AuthError(e.message));
      }
    });
    on<AuthLogoutRequested>((event, emit) async {
      emit(AuthLoading());
      await authService.signOut();
      emit(AuthUnauthenticated());
    });
  }
}
