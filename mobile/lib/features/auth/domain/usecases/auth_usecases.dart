import '../../../../core/error/result.dart';
import '../entities/login_request.dart';
import '../entities/usuario.dart';
import '../repositories/auth_repository.dart';

/// Fallo de validacion de formulario.
///
/// Lo produce el propio caso de uso antes de gastar una peticion, por eso es un
/// [Failure] mas y no una excepcion.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Caso de uso: iniciar sesion.
///
/// Existe para que el BLoC no orchestre logica de negocio. Si manana el login
/// cambia (biometria, OTP, SSO municipal), se toca aqui y no en la UI.
class LoginUseCase {
  const LoginUseCase(this._repo);

  final AuthRepository _repo;

  Future<Result<Usuario>> call(String dni, String password) async {
    final dniLimpio = dni.trim();
    if (dniLimpio.isEmpty) {
      return const Err(ValidationFailure('Ingresa tu DNI'));
    }
    if (dniLimpio.length < 8) {
      return const Err(ValidationFailure('El DNI debe tener 8 digitos'));
    }
    if (password.isEmpty) {
      return const Err(ValidationFailure('Ingresa tu contrasena'));
    }

    try {
      final session = await _repo.login(
        LoginRequest(dni: dniLimpio, password: password),
      );
      return Ok(session.usuario);
    } on Failure catch (f) {
      return Err(f);
    }
  }
}

/// Caso de uso: cerrar sesion revocando el refresh en el servidor.
class LogoutUseCase {
  const LogoutUseCase(this._repo);

  final AuthRepository _repo;

  Future<void> call(String? refreshToken) => _repo.logout(refreshToken);
}

/// Caso de uso: recuperar la sesion al abrir la app.
class RestoreSessionUseCase {
  const RestoreSessionUseCase(this._repo);

  final AuthRepository _repo;

  Future<Usuario?> call() => _repo.restoreSession();
}

/// Caso de uso: validar la sesion contra el backend en caliente.
///
/// Un access token puede expirar mientras la app esta en segundo plano.
class VerifySessionUseCase {
  const VerifySessionUseCase(this._repo);

  final AuthRepository _repo;

  Future<Usuario?> call() async {
    try {
      return await _repo.me();
    } on Failure {
      return null;
    }
  }
}