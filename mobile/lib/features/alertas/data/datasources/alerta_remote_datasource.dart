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
  });
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

    return _api.post<AlertaSos>(
      '/alertas',
      body: <String, dynamic>{
        'latitud': latitud,
        'longitud': longitud,
        'precisionM': ?precisionM,
        'origen': 'APP',
      },
      headers: dispositivo == null ? null : {'X-Device-Id': dispositivo},
      parse: (data) {
        if (data is! Map) {
          throw const NetworkFailure(
            'El servidor devolvio una respuesta inesperada.',
          );
        }
        final id = data['id'];
        final token = data['sessionToken'];
        if (id is! String || id.isEmpty) {
          throw const NetworkFailure(
            'El servidor no devolvio el id de la alerta.',
          );
        }
        if (token is! String || token.isEmpty) {
          throw const NetworkFailure(
            'El servidor no entrego el token de seguimiento.',
          );
        }
        return AlertaSos(alertaId: id, sessionToken: token);
      },
      publico: true,
    );
  }
}
