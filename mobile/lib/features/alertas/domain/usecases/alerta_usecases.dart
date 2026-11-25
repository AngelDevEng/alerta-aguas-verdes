import '../../../../core/error/result.dart';
import '../entities/alerta_sos.dart';
import '../repositories/alerta_repository.dart';

/// Envia un SOS con la posicion dada (`POST /alertas`).
///
/// Valida las coordenadas antes de gastar la peticion: el backend rechaza
/// cualquier latitud fuera de rango con un 422, y en una emergencia el usuario
/// necesita el mensaje local e inmediato, no un round-trip.
///
/// Si [sinUbicacion] es true se omite la validacion de rango: se envia igual
/// (perder el SOS es peor que no tener coordenadas) y el backend marca la
/// alerta como "Sin ubicacion".
class EnviarSosUseCase {
  const EnviarSosUseCase(this._repo);

  final AlertaRepository _repo;

  Future<Result<AlertaSos>> call({
    required double latitud,
    required double longitud,
    double? precisionM,
    bool sinUbicacion = false,
    String? idempotencyKey,
  }) async {
    if (!sinUbicacion &&
        (!latitud.isFinite ||
            !longitud.isFinite ||
            latitud < -90 ||
            latitud > 90 ||
            longitud < -180 ||
            longitud > 180)) {
      return const Err<AlertaSos>(
        ValidationFailure(
          'La ubicacion recibida no es valida. Revisa el GPS e intenta de nuevo.',
        ),
      );
    }

    // Una precision ilegible no invalida el SOS: se omite en vez de perder
    // la alerta por un dato extra.
    final precision =
        precisionM != null && precisionM.isFinite && precisionM >= 0
            ? precisionM
            : null;

    return _repo.crearSos(
      latitud: latitud,
      longitud: longitud,
      precisionM: precision,
      sinUbicacion: sinUbicacion,
      idempotencyKey: idempotencyKey,
    );
  }
}

/// Cambia el estado de una alerta (ACEPTADA, ATENDIDA, CANCELADA, FALSA).
class CambiarEstadoAlertaUseCase {
  const CambiarEstadoAlertaUseCase(this._repo);

  final AlertaRepository _repo;

  Future<Result<Map<String, dynamic>>> call(String id, String estado, {String? unidadId}) =>
      _repo.cambiarEstado(id, estado, unidadId: unidadId);
}