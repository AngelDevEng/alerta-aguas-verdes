import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/core/network/api_client.dart';

/// Cubre el mapeo status HTTP -> tipo de [Failure].
///
/// Este mapeo estuvo roto: `validateStatus` aceptaba los 4xx, asi que
/// `toFailure` nunca recibia el status y un 403 terminaba siendo un
/// `NetworkFailure` con el texto de un error de cast. Los tests fijan el
/// contrato para que un cambio en `validateStatus` no lo vuelva a romper sin
/// que se note.
void main() {
  DioException http(int status, {Object? data}) => DioException(
        requestOptions: RequestOptions(path: '/prueba'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/prueba'),
          statusCode: status,
          data: data,
        ),
        type: DioExceptionType.badResponse,
      );

  group('toFailure por status', () {
    test('401 -> AuthFailure, que no es reintentable', () {
      final f = ApiClient.toFailure(http(401, data: {
        'statusCode': 401,
        'message': 'Token invalido o expirado',
      }));

      expect(f, isA<AuthFailure>());
      expect(f.message, 'Token invalido o expirado');
      // Reintentable implicaria infinitos refreshes contra un token muerto.
      expect(f.reintentable, isFalse);
    });

    test('403 -> ForbiddenFailure, no AuthFailure', () {
      final f = ApiClient.toFailure(http(403, data: {
        'statusCode': 403,
        'message': 'Requiere uno de estos roles: ADMIN',
      }));

      // La distincion importa: `ForbiddenFailure` no dispara refresh y la UI
      // explica que falta permiso en vez de echar al login.
      expect(f, isA<ForbiddenFailure>());
      expect(f, isNot(isA<AuthFailure>()));
      expect(f.message, contains('ADMIN'));
    });

    test('404 -> NotFoundFailure', () {
      expect(ApiClient.toFailure(http(404)), isA<NotFoundFailure>());
    });

    test('409 -> ConflictFailure (evidencia duplicada por hash)', () {
      final f = ApiClient.toFailure(http(409, data: {
        'statusCode': 409,
        'message': 'La evidencia ya fue cargada',
      }));

      expect(f, isA<ConflictFailure>());
      expect(f.message, 'La evidencia ya fue cargada');
    });

    test('429 -> RateLimitedFailure y si es reintentable', () {
      final f = ApiClient.toFailure(http(429));
      expect(f, isA<RateLimitedFailure>());
      expect(f.reintentable, isTrue);
    });

    test('400 y 422 -> ValidationFailure', () {
      expect(ApiClient.toFailure(http(400)), isA<ValidationFailure>());
      expect(ApiClient.toFailure(http(422)), isA<ValidationFailure>());
    });

    test('422 usa el texto de ValidationPipe sin corchetes', () {
      // `ValidationPipe` responde `message` como lista. Un `toString()` a secas
      // dejaba "[dni must be a string, password must be a string]" en pantalla.
      final f = ApiClient.toFailure(http(422, data: {
        'statusCode': 422,
        'message': ['dni must be a string', 'password must be a string'],
      }));

      expect(f, isA<ValidationFailure>());
      expect(f.message, 'dni must be a string. password must be a string');
      expect(f.message, isNot(contains('[')));
    });

    test('5xx -> ServerFailure que conserva el codigo', () {
      final f = ApiClient.toFailure(http(503));
      expect(f, isA<ServerFailure>());
      expect((f as ServerFailure).statusCode, 503);
      expect(f.reintentable, isTrue);
    });

    test('status sin cuerpo sigue produciendo una falla tipada', () {
      expect(ApiClient.toFailure(http(500)), isA<ServerFailure>());
      expect(ApiClient.toFailure(http(403)), isA<ForbiddenFailure>());
    });
  });

  group('toFailure por tipo de DioException', () {
    test('timeouts -> TimeoutFailure', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final e = DioException(
          requestOptions: RequestOptions(path: '/prueba'),
          type: t,
        );
        expect(ApiClient.toFailure(e), isA<TimeoutFailure>(), reason: '$t');
      }
    });

    test('TimeoutFailure es NetworkFailure: la UI reintenta igual', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/prueba'),
        type: DioExceptionType.connectionTimeout,
      );
      final f = ApiClient.toFailure(e);

      expect(f, isA<NetworkFailure>());
      expect(f.reintentable, isTrue);
      // El mensaje debe ser accionable: "espera", no "sin conexion".
      expect(f.message, contains('tardo'));
    });

    test('sin respuesta -> NetworkFailure reintentable', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/prueba'),
        type: DioExceptionType.connectionError,
      );
      expect(ApiClient.toFailure(e), isA<NetworkFailure>());
      expect(ApiClient.toFailure(e).reintentable, isTrue);
    });
  });

  group('toFailure con errores de parsing', () {
    // Reproduce el `parse` de un DTO cuando el backend devuelve algo que no
    // es el tipo esperado (por ejemplo `null` donde va un `String`).
    Object errorDeCast() {
      final dynamic v = null;
      try {
        return v as String;
      } on TypeError catch (e) {
        // Esto es lo que `ApiClient` recibe del `catch (e)` del datasource.
        return e;
      }
    }

    test('respuesta con forma inesperada no filtra el volcado de pila', () {
      // Es lo que pasaba con los 4xx antes del arreglo: el `parse` reventaba
      // con un TypeError y el mensaje crudo llegaba a la pantalla.
      final f = ApiClient.toFailure(errorDeCast());

      expect(f, isA<NetworkFailure>());
      expect(f.message, 'El servidor devolvio una respuesta inesperada.');
      expect(f.message, isNot(contains('subtype')));
      expect(f.message, isNot(contains('TypeError')));
    });

    test('una Failure lanzada por un DTO se respeta sin envolver', () {
      final original = const ValidationFailure('dni invalido');
      expect(identical(ApiClient.toFailure(original), original), isTrue);
    });
  });

  group('ApiClient.esExito', () {
    test('solo 2xx se considera exito', () {
      // Si esto falla, el refresh de token y todo el mapeo de arriba quedan
      // muertos: dio resolveria en onResponse y nunca lanzaria.
      expect(ApiClient.esExito(200), isTrue);
      expect(ApiClient.esExito(204), isTrue);

      for (final status in [301, 400, 401, 403, 404, 409, 422, 429]) {
        expect(ApiClient.esExito(status), isFalse, reason: '$status debe lanzar');
      }
      for (final status in [500, 502, 503]) {
        expect(ApiClient.esExito(status), isFalse, reason: '$status debe lanzar');
      }
    });

    test('la instancia real usa ese mismo predicado', () {
      // Evita que alguien cambie el constructor y deje el test probando una
      // copia de la logica que ya no esta en produccion.
      final api = ApiClient(baseUrl: 'http://localhost:0/api');
      expect(api.dio.options.validateStatus, isNotNull);

      expect(api.dio.options.validateStatus(200), isTrue);
      expect(api.dio.options.validateStatus(403), isFalse);
      expect(api.dio.options.validateStatus(500), isFalse);
    });
  });
}