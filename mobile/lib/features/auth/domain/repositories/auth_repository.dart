import '../entities/login_request.dart';
import '../entities/usuario.dart';

/// Contrato de autenticacion.
///
/// La interfaz vive en `domain/` y la implementacion en `data/`: el caso de uso
/// depende de esta abstraccion, nunca de `Dio` ni de `TokenStore`. Gracias a eso
/// se puede probar con un fake sin levantar Flutter.
abstract interface class AuthRepository {
  Future<AuthSession> login(LoginRequest request);

  /// Usuario cacheado localmente, o `null` si no hay sesion.
  Future<Usuario?> restoreSession();

  Future<Usuario> me();

  /// Revoca el refresh en el servidor y limpia los tokens locales siempre.
  Future<void> logout(String? refreshToken);
}