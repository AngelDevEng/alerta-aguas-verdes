/// Jerarquia de fallas de la aplicacion.
///
/// Separada de `result.dart` a proposito: aca viven los *tipos* de fallo (que
/// puede reaccionar la UI) y en `result.dart` el *envoltorio* (`Result`, `Ok`,
/// `Err`). `result.dart` reexporta este archivo, asi que los imports existentes
/// siguen funcionando.
///
/// El criterio de diseno: cada tipo existe porque alguna pantalla necesita
/// *decidir* algo distinto segun el fallo. Un unico `NetworkFailure` con un
/// mensaje obligaba a las pantallas a comparar strings, que es fragil y no
/// sobrevive a que el backend cambie un texto.
library;

/// Falla de dominio: error de negocio o de transporte, independiente del HTTP.
///
/// Es `abstract` y no `sealed` a proposito: cada feature puede definir sus
/// propias fallas (por ejemplo `ValidacionLocalFailure` en auth).
abstract class Failure {
  const Failure(this.message);

  /// Texto que se muestra al usuario. Redactado en segunda persona y sin
  /// jerga: "Tu sesion expiro" y no "401 Unauthorized".
  final String message;

  /// Si la app conviene reintentar la misma peticion sin intervencion.
  ///
  /// Lo decide el tipo, no la pantalla: asi ningun widget tiene que saber que
  /// un 503 se reintenta y un 400 no.
  bool get reintentable => false;

  @override
  String toString() => '$runtimeType: $message';
}

/// Sin conexion: no hubo respuesta del servidor.
///
/// Es reintentable porque la causa (senal, aire, timeout) es transitoria.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexion a la red']);

  @override
  bool get reintentable => true;
}

/// El servidor tardo en responder. Es un subcaso de [NetworkFailure] porque la
/// UI reacciona igual (reintentar), pero el mensaje es accionable: el operador
/// sabe que esperar mas, no que esta sin cobertura.
class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure([
    super.message = 'El servidor tardo demasiado. Intenta de nuevo.',
  ]);
}

/// El servidor respondio 5xx.
///
/// Reintentable, pero con caution: un 500 en `POST /incidencias` puede significar
/// que la escritura si se aplico y la respuesta se perdio. Por eso los
/// formularios de alta no lo tratan como seguro reintentar.
class ServerFailure extends Failure {
  const ServerFailure(this.statusCode, super.message);

  final int statusCode;

  @override
  bool get reintentable => true;
}

/// Credenciales ausentes, invalidas o expiradas sin posibilidad de refresh.
///
/// No reintentable: el `RefreshInterceptor` ya intento renovar el token; si
/// llega aca, hay que volver a pedir credenciales.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Sesion expirada. Inicia sesion otra vez.']);
}

/// El rol del usuario no alcanza para la operacion (403).
///
/// Distinta de [AuthFailure] a proposito: el usuario esta bien logueado, no
/// tiene permiso. La UI reacciona distinto (explicar que necesita otro rol,
/// no mandar al login) y sobre todo *no* debe disparar un refresh inútil.
class ForbiddenFailure extends Failure {
  const ForbiddenFailure([
    super.message = 'Tu rol no tiene permiso para esta accion.',
  ]);
}

/// El recurso no existe (404).
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso no encontrado']);
}

/// Peticion mal formada o datos invalidos (400/422).
///
/// [campos] conserva el detalle por campo cuando NestJS lo envia, para que el
/// formulario pueda marcar el input concreto en vez de pintarse entero de rojo.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.campos = const <String, String>{}});

  /// Errores por nombre de campo. Vacio si el backend no los detallo.
  final Map<String, String> campos;

  bool get tieneCampos => campos.isNotEmpty;
}

/// Conflicto de estado (409).
///
/// El caso real del backend: subir dos veces la misma evidencia choca con el
/// indice unico de `hash_sha256`. Es el unico 409 de la API y no es un error del
/// usuario, asi que merece su propio tipo.
class ConflictFailure extends Failure {
  const ConflictFailure([
    super.message = 'Este registro ya existe.',
  ]);
}

/// Demasiadas peticiones (429).
class RateLimitedFailure extends Failure {
  const RateLimitedFailure([
    super.message = 'Demasiados intentos. Espera un momento.',
  ]);

  @override
  bool get reintentable => true;
}

/// Fallo local: GPS denegado, sin permiso, archivo ilegible, etc.
///
/// Nunca proviene de la red: no tiene status code y su mensaje suele ofrecer
/// una accion ("activa el GPS").
class LocalFailure extends Failure {
  const LocalFailure(super.message);
}
