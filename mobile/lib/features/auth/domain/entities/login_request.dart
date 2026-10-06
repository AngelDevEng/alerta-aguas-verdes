/// Credenciales de acceso.
///
/// Vive en `domain/` (no en `data/`) para que el caso de uso no dependa del
/// formato de la API. El repositorio lo traduce al JSON del backend.
class LoginRequest {
  const LoginRequest({required this.dni, required this.password});

  final String dni;
  final String password;
}

/// Acceso de sereno por placa de su unidad (POST /auth/login/patrullero).
///
/// La placa viaja tal cual la tecleó el usuario: la normalizacion
/// (mayúsculas, sin espacios) la hacen el caso de uso y el backend, para que
/// haya un solo lugar que decide la forma canónica.
class LoginPlacaRequest {
  const LoginPlacaRequest({required this.placa, required this.password});

  final String placa;
  final String password;
}

/// Refresh token que se revoca en el backend al cerrar sesion.
class LogoutRequest {
  const LogoutRequest({required this.refreshToken});

  final String refreshToken;
}