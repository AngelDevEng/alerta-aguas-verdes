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

  // Sin casts duros: ante un cuerpo inesperado devuelve strings vacios en vez de
  // lanzar. La forma del exito esta garantizada por el backend, pero parsear no
  // debe ser la capa que reporta el error.
  factory AuthSessionDto.fromJson(Map<String, dynamic> json) => AuthSessionDto(
        accessToken: json['accessToken']?.toString() ??
            json['token']?.toString() ??
            '',
        refreshToken: json['refreshToken']?.toString() ?? '',
        expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 900,
        usuario: UsuarioDto.fromJson(
          Map<String, dynamic>.from(
            (json['usuario'] as Map?) ??
                // El backend tambien expone el usuario plano.
                <String, dynamic>{
                  'id': json['id'],
                  'dni': json['dni'],
                  'nombreCompleto': json['nombreCompleto'] ?? json['nombre'],
                  'rol': json['rol'],
                  'email': json['email'],
                },
          ),
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