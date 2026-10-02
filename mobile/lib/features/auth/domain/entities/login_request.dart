/// Credenciales de acceso.
///
/// Vive en `domain/` (no en `data/`) para que el caso de uso no dependa del
/// formato de la API. El repositorio lo traduce al JSON del backend.
class LoginRequest {
  const LoginRequest({required this.dni, required this.password});

  final String dni;
  final String password;
}

/// Refresh token que se revoca en el backend al cerrar sesion.
class LogoutRequest {
  const LogoutRequest({required this.refreshToken});

  final String refreshToken;
}