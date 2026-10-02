import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../domain/usecases/auth_usecases.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// ViewModel de la sesion.
///
/// Solo orquesta casos de uso: no conoce `Dio`, ni el keychain, ni el formato
/// JSON. Eso permite testearlo con `bloc_test` y casos de uso falsos.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Formals posicionales iniciales: los parametros con nombre no admiten
/// `this._campo` (Dart forbids nombres privados en parametros con nombre), por
/// eso se inyectan posicionalmente. Los tipos los distinguen.
  AuthBloc(
    this._login,
    this._logout,
    this._restore,
    this._verify,
  ) : super(const AuthUnknown()) {
    on<AuthIniciado>(_onIniciado);
    on<AuthLoginSolicitado>(_onLogin);
    on<AuthLogoutSolicitado>(_onLogout);
  }

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final RestoreSessionUseCase _restore;
  final VerifySessionUseCase _verify;

  Future<void> _onIniciado(AuthIniciado event, Emitter<AuthState> emit) async {
    final cached = await _restore();
    if (cached == null) {
      emit(const AuthNoAutenticado());
      return;
    }
    // Emitimos desde cache para pintar la UI sin esperar al round-trip, y
    // verificamos en paralelo: si el token ya vencio, cae al login.
    emit(AuthAutenticado(cached));
    final vivo = await _verify();
    if (vivo == null) emit(const AuthNoAutenticado(mensaje: 'Sesion expirada'));
  }

  Future<void> _onLogin(AuthLoginSolicitado event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final res = await _login(event.dni, event.password);
    switch (res) {
      case Ok(:final value):
        emit(AuthAutenticado(value));
      case Err(:final failure):
        emit(AuthNoAutenticado(mensaje: failure.message));
    }
  }

  Future<void> _onLogout(AuthLogoutSolicitado event, Emitter<AuthState> emit) async {
    await _logout(null);
    emit(const AuthNoAutenticado());
  }
}