import 'failures.dart';

// La jerarquia de fallas vive en `failures.dart`. Se reexporta para que los
// imports existentes (`import '.../core/error/result.dart'`) sigan resolviendo
// sin tocar 40 archivos.
export 'failures.dart';

/// Resultado explicito de una operacion.
///
/// Evita `try/catch` en widgets y `null` ambiguos: el compilador obliga a
/// manejar ambos casos del camino feliz y del fallido.
///
/// Es `sealed` (a diferencia de [Failure]) porque el `switch` sobre el
/// resultado si debe ser exhaustivo.
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