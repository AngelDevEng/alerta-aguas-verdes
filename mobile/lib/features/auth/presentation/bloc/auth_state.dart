import 'package:equatable/equatable.dart';

import '../../domain/entities/usuario.dart';

/// Estados de la sesion.
///
/// `AuthUnknown` permite que el router espere la rehidratacion antes de decidir
/// entre `/login` y el mapa. Sin ese estado, la app abriria el login y luego
/// saltaria al mapa con un parpadeo en cada arranque.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Sesion aun no determinada: se esta rehidratando desde el keychain.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// Login en curso.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Sesion activa.
class AuthAutenticado extends AuthState {
  const AuthAutenticado(this.usuario);

  final Usuario usuario;

  @override
  List<Object?> get props => [usuario];
}

/// Sin sesion. `mensaje` muestra el error del ultimo intento fallido.
class AuthNoAutenticado extends AuthState {
  const AuthNoAutenticado({this.mensaje});

  final String? mensaje;

  @override
  List<Object?> get props => [mensaje];
}