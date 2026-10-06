import 'package:equatable/equatable.dart';

/// Eventos del BLoC de autenticacion.
///
/// Un `sealed` hierarchy de eventos obliga a que el `switch` del BLoC sea
/// exhaustivo: si manana se agrega `AuthBiometriaSolicitado`, el compilador
/// avisa en vez de que el evento se ignore en silencio.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Se dispara al arrancar la app para rehidratar la sesion guardada.
class AuthIniciado extends AuthEvent {
  const AuthIniciado();
}

class AuthLoginSolicitado extends AuthEvent {
  const AuthLoginSolicitado({required this.dni, required this.password});

  final String dni;
  final String password;

  @override
  List<Object?> get props => [dni, password];
}

/// Login de sereno por placa de su unidad.
class AuthLoginPlacaSolicitado extends AuthEvent {
  const AuthLoginPlacaSolicitado({
    required this.placa,
    required this.password,
  });

  final String placa;
  final String password;

  @override
  List<Object?> get props => [placa, password];
}

class AuthLogoutSolicitado extends AuthEvent {
  const AuthLogoutSolicitado();
}