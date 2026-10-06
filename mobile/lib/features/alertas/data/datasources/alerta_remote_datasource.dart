import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';

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
/// leida: ese cuerpo es el contrato que se parsea.
abstract interface class AlertaRemoteDataSource {
  Future<Result<String>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
  });
}

class AlertaRemoteDataSourceImpl implements AlertaRemoteDataSource {
  AlertaRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<String>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
  }) =>
      _api.post<String>(
        '/alertas',
        body: <String, dynamic>{
          'latitud': latitud,
          'longitud': longitud,
          'precisionM': ?precisionM,
          'origen': 'APP',
        },
        parse: (data) {
          final id = data is Map ? data['id'] : null;
          if (id is! String || id.isEmpty) {
            throw const NetworkFailure(
              'El servidor devolvio una respuesta inesperada.',
            );
          }
          return id;
        },
      );
}
