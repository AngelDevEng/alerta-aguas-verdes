import 'dart:async';

import 'package:dio/dio.dart';

import '../error/result.dart';

/// Cliente HTTP unico de la app.
///
/// Configura timeouts y SSL de Supabase/Render una sola vez. Los headers de
/// autorizacion y la logica de refresh viven en los interceptores.
class ApiClient {
  ApiClient({required String baseUrl, Dio? dio})
      : dio = dio ?? Dio() {
    this.dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // Render y Supabase presentan certificados validos; si se usa un
      // certificado autofirmado en staging, extraer la excepcion aqui.
      //
      // Solo 2xx se considera exito, y es load-bearing. Con `status < 500` dio
      // resolvia los 4xx en `onResponse` sin lanzar, y entonces:
      //   - `onError` del `RefreshInterceptor` nunca corria, asi que un token
      //     expirado no se refrescaba nunca;
      //   - `toFailure` nunca recibia el status, asi que un 403 terminaba
      //     reventando dentro de `parse` y el TypeError llegaba a pantalla.
      validateStatus: esExito,
    );
  }

  /// Unico predicado de "esto fue exitoso" del proyecto.
  ///
  /// Vive aca y no en una lambda inline para que los tests puedan fijarlo: es
  /// el tipo de flag que se cambia por costumbre y rompe en silencio todo lo
  /// que depende de los errores.
  static bool esExito(int? status) => status != null && status >= 200 && status < 300;

  final Dio dio;

  /// Traduce cualquier error de transporte o parsing a una [Failure] tipada.
  ///
  /// Es el unico lugar del proyecto donde se decide que significa un codigo
  /// HTTP. Las pantallas reaccionan al *tipo* ([ForbiddenFailure],
  /// [ConflictFailure], ...) y nunca al texto del backend, que puede cambiar
  /// sin que nadie actualice la app.
  static Failure toFailure(Object error, {int? statusCode}) {
    // Un DTO puede decidir lanzar una falla propia (por ejemplo
    // `ValidationFailure` al parsear una respuesta con forma inesperada).
    // Se respeta tal cual en vez de envolverla en un NetworkFailure que pierde
    // el tipo.
    if (error is Failure) return error;

    if (error is DioException) {
      // Un timeout es un subcaso de "sin conexion" con mensaje distinto: el
      // operador necesita saber que esperar, no que esta sin cobertura.
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return const TimeoutFailure();
      }

      final code = statusCode ?? error.response?.statusCode;
      if (code == null) {
        return const NetworkFailure();
      }

      final mensaje = _mensajeDe(error.response?.data);
      return switch (code) {
        401 => AuthFailure(mensaje ?? 'Sesion expirada. Inicia sesion otra vez.'),
        403 => ForbiddenFailure(mensaje ?? 'Tu rol no tiene permiso para esta accion.'),
        404 => NotFoundFailure(mensaje ?? 'El recurso ya no existe.'),
        // 409: el unico del backend es el indice unico de `hash_sha256` al
        // resubir la misma evidencia. No es un error del usuario.
        409 => ConflictFailure(mensaje ?? 'Este registro ya fue cargado.'),
        429 => const RateLimitedFailure(),
        400 || 422 => ValidationFailure(
            mensaje ?? 'Revisa los datos e intenta de nuevo.',
            campos: _camposDe(error.response?.data),
          ),
        >= 500 => ServerFailure(code, 'El servidor fallo ($code). Intenta de nuevo.'),
        _ => NetworkFailure(mensaje ?? 'No se pudo completar la operacion.'),
      };
    }

    // Un TypeError de `parse` significa que la respuesta no tiene la forma
    // esperada: un problema del contrato, no de la red. El mensaje se
    // sanitiza para no volcar un volcado de stack en pantalla.
    if (error is TypeError || error is FormatException || error is StateError) {
      return const NetworkFailure('El servidor devolvio una respuesta inesperada.');
    }
    return NetworkFailure(error.toString());
  }

  /// Extrae el mensaje de un error de NestJS.
  ///
  /// `ValidationPipe` responde `message` como `List<String>` cuando hay varios
  /// problemas y como `String` cuando hay uno. `toString()` sobre la lista
  /// devolveria `"[a, b]"`, que es lo que se veia en pantalla.
  static String? _mensajeDe(dynamic data) {
    if (data is! Map) return null;
    final m = data['message'];
    if (m is String && m.trim().isNotEmpty) return m;
    if (m is List && m.isNotEmpty) {
      return m.map((e) => e.toString()).join('. ');
    }
    return null;
  }

  /// Errores por campo, cuando el backend los envia en `errors`.
  ///
  /// NestJS con `ValidationPipe` estandar no los manda (solo la lista de
  /// mensajes), asi que normalmente queda vacio y [ValidationFailure.tieneCampos]
  /// es `false`. El hook queda porque el backend ya lo soporta en otros
  /// handlers y el formulario lo usa para marcar el input concreto.
  static Map<String, String> _camposDe(dynamic data) {
    if (data is! Map) return const {};
    final e = data['errors'];
    if (e is Map) {
      return e.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return const {};
  }

  /// GET tipado. Devuelve [Result] para que el llamador no lance excepciones.
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool publico = false,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final res = await dio.get<dynamic>(
        path,
        queryParameters: query,
        options: _opciones(publico),
      );
      return Ok<T>(parse(res.data));
    } catch (e) {
      return Err<T>(toFailure(e));
    }
  }

  /// POST tipado.
  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    bool publico = false,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final res = await dio.post<dynamic>(
        path,
        data: body,
        options: _opciones(publico),
      );
      return Ok<T>(parse(res.data));
    } catch (e) {
      return Err<T>(toFailure(e));
    }
  }

  /// PATCH tipado. Lo usan las acciones de despacho sobre incidencias.
  Future<Result<T>> patch<T>(
    String path, {
    Object? body,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final res = await dio.patch<dynamic>(path, data: body);
      return Ok<T>(parse(res.data));
    } catch (e) {
      return Err<T>(toFailure(e));
    }
  }

  /// POST multipart para evidencias (foto/audio).
  Future<Result<T>> upload<T>(
    String path, {
    required FormData formData,
    ProgressCallback? onProgress,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final res = await dio.post<dynamic>(
        path,
        data: formData,
        onSendProgress: onProgress,
      );
      return Ok<T>(parse(res.data));
    } catch (e) {
      return Err<T>(toFailure(e));
    }
  }

  /// Marca la peticion como publica para que el `AuthInterceptor` no le anexe
  /// el token.
  static Options _opciones(bool publico) =>
      publico ? Options(extra: const {'public': true}) : Options();
}