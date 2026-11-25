import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/sos_session_store.dart';
import '../../domain/entities/alerta_sos.dart';

/// Fuente remota de alertas SOS.
///
/// `POST /alertas` es el unico endpoint publico del backend (`@Public()` en
/// `alertas.controller.ts:21`), pensado para quien pulsa SOS sin cuenta. No
/// se marca `publico: true` en el `ApiClient`: el `AuthInterceptor` solo
/// anade `Authorization` si hay token en el keychain, lo que replica el
/// `Bearer` del legacy sin romper la llamada anonima.
///
/// A cambio de la posicion, el backend crea en una sola transaccion la
/// incidencia EMER (prioridad CRITICA) y la alerta, y devuelve la alerta
/// leida mas el `sessionToken`: ese cuerpo es el contrato que se parsea.
abstract interface class AlertaRemoteDataSource {
  Future<Result<AlertaSos>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
    bool sinUbicacion = false,
    String? idempotencyKey,
  });

  Future<Result<Map<String, dynamic>>> cambiarEstado(String id, String estado, {String? unidadId});
}

class AlertaRemoteDataSourceImpl implements AlertaRemoteDataSource {
  AlertaRemoteDataSourceImpl(this._api, this._sos);

  final ApiClient _api;
  final SosSessionStore _sos;

  @override
  Future<Result<AlertaSos>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
    bool sinUbicacion = false,
    String? idempotencyKey,
  }) async {
    // Sin device id el backend no puede deduplicar; si el almacenamiento seguro
    // falla se envia igual, porque perder el SOS es peor que arriesgar una
    // segunda alerta.
    String? dispositivo;
    try {
      dispositivo = await _sos.deviceId();
    } catch (_) {
      dispositivo = null;
    }

    final headers = <String, String>{
      if (dispositivo != null) 'X-Device-Id': dispositivo,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'Idempotency-Key': idempotencyKey,
    };

    return _api.post<AlertaSos>(
      '/alertas',
      body: <String, dynamic>{
        'latitud': latitud,
        'longitud': longitud,
        'precisionM': ?precisionM,
        'origen': 'APP',
        if (sinUbicacion) 'sinUbicacion': true,
      },
      headers: headers.isEmpty ? null : headers,
      // Timeout corto: ante una red lenta se reintenta con la misma clave en
      // vez de dejar al usuario esperando.
      timeout: const Duration(seconds: 8),
      parse: (data) {
        if (data is! Map) {
          throw const NetworkFailure(
            'El servidor devolvio una respuesta inesperada.',
          );
        }
        final id = data['id'];
        if (id is! String || id.isEmpty) {
          throw const NetworkFailure(
            'El servidor no devolvio el id de la alerta.',
          );
        }
        final token = data['sessionToken'];
        final estado = data['estado'];
        return AlertaSos(
          alertaId: id,
          sessionToken: token is String && token.isNotEmpty ? token : null,
          estado: estado is String ? estado : null,
          sinUbicacion: data['sinUbicacion'] == true,
        );
      },
      publico: true,
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> cambiarEstado(String id, String estado, {String? unidadId}) =>
      _api.patch<Map<String, dynamic>>(
        '/alertas/$id/estado',
        body: <String, dynamic>{
          'estado': estado,
          if (unidadId != null && unidadId.isNotEmpty) 'unidadId': unidadId,
        },
        parse: (data) {
          if (data is! Map) {
            throw const NetworkFailure('Respuesta inesperada del servidor.');
          }
          return Map<String, dynamic>.from(data);
        },
      );
}