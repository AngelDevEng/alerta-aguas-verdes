/// Falla de dominio: error de negocio o de transporte, independiente del HTTP.
///
/// Se usa en vez de excepciones para que `domain/` nunca dependa de `dio`.
///
/// Es `abstract` y no `sealed` a proposito: cada feature define sus propias
/// fallas (por ejemplo `ValidationFailure` en auth). `Result` si es `sealed`,
/// porque ese si debe ser exhaustivo en los `switch`.
abstract class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Sin conexion: no hubo respuesta del servidor.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexion a la red']);
}

/// El servidor respondio 4xx/5xx.
class ServerFailure extends Failure {
  const ServerFailure(this.statusCode, super.message);

  final int statusCode;
}

/// Credenciales ausentes, invalidas o expiradas sin possibility de refresh.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Sesion expirada. Inicia sesion otra vez.']);
}

/// El recurso solicitado no existe.
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso no encontrado']);
}

/// Fallo local: GPS denegado, sin permiso, cache corrupta, etc.
class LocalFailure extends Failure {
  const LocalFailure(super.message);
}

/// Resultado explicito de una operacion.
///
/// Evita `try/catch` en widgets y `null` ambiguos: el compilador obliga a
/// manejar ambos casos del camino feliz y del fallido.
sealed class Result<T> {
  const Result();

  /// Devuelve el valor o `null` si fallo. Para lecturas tolerantes.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// Devuelve el valor o lanza. Usar solo cuando el fallo ya fue resuelto antes.
  T get valueOrThrow => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>(:final failure) => throw failure,
      };

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  R fold<R>(R Function(Failure f) onErr, R Function(T v) onOk) => switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  Result<R> map<R>(R Function(T v) transform) => switch (this) {
        Ok<T>(:final value) => Ok(transform(value)),
        Err<T>(:final failure) => Err(failure),
      };
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}