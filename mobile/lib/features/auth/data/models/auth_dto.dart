import 'package:equatable/equatable.dart';

/// DTO de `POST /auth/login` y `POST /auth/refresh`.
///
/// Refleja el camelCase que devuelve el backend NestJS. Se mantiene en `data/`
/// porque es un detalle del transporte.
class AuthSessionDto extends Equatable {
  const AuthSessionDto({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.usuario,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UsuarioDto usuario;

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) => AuthSessionDto(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 900,
        usuario: UsuarioDto.fromJson(
          Map<String, dynamic>.from(json['usuario'] as Map),
        ),
      );

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresIn, usuario];
}

/// DTO de usuario segun las rutas `/auth/login`, `/auth/refresh` y `/auth/me`.
class UsuarioDto extends Equatable {
  const UsuarioDto({
    required this.id,
    required this.dni,
    required this.nombreCompleto,
    required this.rol,
    this.email,
  });

  final String id;
  final String dni;
  final String nombreCompleto;
  final String rol;
  final String? email;

  factory UsuarioDto.fromJson(Map<String, dynamic> json) => UsuarioDto(
        id: json['id']?.toString() ?? '',
        dni: json['dni']?.toString() ?? '',
        nombreCompleto: json['nombreCompleto']?.toString() ?? '',
        rol: json['rol']?.toString() ?? 'CIUDADANO',
        email: json['email']?.toString(),
      );

  @override
  List<Object?> get props => [id, dni, nombreCompleto, rol, email];
}