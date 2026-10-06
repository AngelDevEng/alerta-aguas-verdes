import 'dart:convert';
import 'dart:io';

import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/core/network/api_client.dart';
import 'package:alerta_aguas_verdes/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:alerta_aguas_verdes/features/auth/data/models/auth_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cubre el reporte "type 'Null' is not a subtype of type 'String' in type cast"
/// al iniciar sesion con credenciales incorrectas.
///
/// Causa raiz: `validateStatus` aceptaba cualquier status < 500, asi que un 401
/// pasaba por la rama feliz y `AuthSessionDto.fromJson` hacia
/// `json['accessToken'] as String` sobre un cuerpo de error sin ese campo.
///
/// El 401 se sirve desde un `HttpServer` real y no con un interceptor, porque
/// un interceptor que resuelve la respuesta se salta `validateStatus` y no
/// ejercitaria el camino que rompia.
void main() {
  // Cuerpo exacto que devuelve el backend ante credenciales invalidas.
  final cuerpo401 = <String, dynamic>{
    'success': false,
    'statusCode': 401,
    'mensaje': 'Credenciales invalidas',
    'message': 'Credenciales invalidas',
    'mensajes': ['Credenciales invalidas'],
    'ruta': '/api/v1/auth/login',
  };

  late HttpServer server;
  late String baseUrl;

  /// Levanta un servidor que siempre responde `status` con `cuerpo`.
  Future<void> servir(int status, Map<String, dynamic> cuerpo) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}/api/v1';
    server.listen((req) async {
      req.response.statusCode = status;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(cuerpo));
      await req.response.close();
    });
  }

  tearDown(() async {
    await server.close(force: true);
  });

  test('login con 401 no lanza cast de null y devuelve AuthFailure', () async {
    await servir(401, cuerpo401);
    final ds = AuthRemoteDataSourceImpl(ApiClient(baseUrl: baseUrl));

    final res = await ds.login(dni: '00000002', password: 'incorrecta');

    expect(res, isA<Err<AuthSessionDto>>());
    expect((res as Err<AuthSessionDto>).failure, isA<AuthFailure>());
  });

  test('el mensaje del login incorrecto es "Credenciales incorrectas"', () async {
    await servir(401, cuerpo401);
    final ds = AuthRemoteDataSourceImpl(ApiClient(baseUrl: baseUrl));

    final res = await ds.login(dni: '00000002', password: 'incorrecta');

    expect((res as Err<AuthSessionDto>).failure.message,
        'Credenciales incorrectas');
  });

  test('usuario inexistente (mismo 401) da el mismo mensaje', () async {
    await servir(401, cuerpo401);
    final ds = AuthRemoteDataSourceImpl(ApiClient(baseUrl: baseUrl));

    final res = await ds.login(dni: '09999999', password: 'incorrecta');

    expect((res as Err<AuthSessionDto>).failure.message,
        'Credenciales incorrectas');
  });

  test('login por placa con 401 da el mismo mensaje genérico', () async {
    await servir(401, {...cuerpo401, 'ruta': '/api/v1/auth/login/patrullero'});
    final ds = AuthRemoteDataSourceImpl(ApiClient(baseUrl: baseUrl));

    final res =
        await ds.loginPorPlaca(placa: 'EGA-999', password: 'incorrecta');

    expect(res, isA<Err<AuthSessionDto>>());
    expect((res as Err<AuthSessionDto>).failure, isA<AuthFailure>());
    expect(res.failure.message, 'Credenciales incorrectas');
  });

  test('el login por placa exitoso reutiliza el mismo contrato', () async {
    await servir(200, {
      'success': true,
      'accessToken': 'jwt-sereno',
      'refreshToken': 'refresh-sereno',
      'usuario': {
        'id': 'uuid-3',
        'dni': '00000003',
        'nombreCompleto': 'Sereno Demo',
        'rol': 'SERENO',
      },
      'unidadId': 'uuid-unidad-1',
    });
    final ds = AuthRemoteDataSourceImpl(ApiClient(baseUrl: baseUrl));

    final res = await ds.loginPorPlaca(placa: 'EGA-999', password: 'clave');

    expect(res, isA<Ok<AuthSessionDto>>());
    final dto = (res as Ok<AuthSessionDto>).value;
    expect(dto.accessToken, 'jwt-sereno');
    expect(dto.usuario.rol, 'SERENO');
  });

  test('parsear un cuerpo de error no lanza excepcion', () {
    // Si el guard de parseo se revirtiera, esto reventaria con TypeError.
    expect(() => AuthSessionDto.fromJson(cuerpo401), returnsNormally);
  });

  test('el login exitoso lee el contrato plano y el anidado', () async {
    await servir(200, {
      'success': true,
      'token': 'jwt-plano',
      'accessToken': 'jwt-plano',
      'refreshToken': 'refresh',
      'expiresIn': 900,
      'id': 'uuid-1',
      'dni': '00000002',
      'nombre': 'Admin Municipal',
      'nombreCompleto': 'Admin Municipal',
      'rol': 'ADMIN',
      'usuario': {
        'id': 'uuid-1',
        'dni': '00000002',
        'nombreCompleto': 'Admin Municipal',
        'rol': 'ADMIN',
      },
    });
    final ds = AuthRemoteDataSourceImpl(ApiClient(baseUrl: baseUrl));

    final res = await ds.login(dni: '00000002', password: 'la-correcta');

    expect(res, isA<Ok<AuthSessionDto>>());
    final dto = (res as Ok<AuthSessionDto>).value;
    expect(dto.accessToken, 'jwt-plano');
    expect(dto.refreshToken, 'refresh');
    expect(dto.usuario.rol, 'ADMIN');
    expect(dto.usuario.nombreCompleto, 'Admin Municipal');
  });

  test('el cuerpo plano sin "usuario" tambien se parsea', () {
    final dto = AuthSessionDto.fromJson({
      'token': 'jwt-plano',
      'accessToken': 'jwt-plano',
      'refreshToken': 'r',
      'id': 'uuid-2',
      'dni': '00000003',
      'nombre': 'Sereno Demo',
      'rol': 'SERENO',
    });

    expect(dto.accessToken, 'jwt-plano');
    expect(dto.usuario.dni, '00000003');
    expect(dto.usuario.nombreCompleto, 'Sereno Demo');
  });
}