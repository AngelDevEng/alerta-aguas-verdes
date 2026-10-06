import '../../../../core/error/result.dart';
import '../../domain/repositories/alerta_repository.dart';

/// Envia un SOS con la posicion dada (`POST /alertas`).
///
/// Valida las coordenadas antes de gastar la peticion: el backend rechaza
/// cualquier latitud fuera de rango con un 422, y en una emergidad el usuario
/// necesita el mensaje local e inmediato, no un round-trip.
class EnviarSosUseCase {
  const EnviarSosUseCase(this._repo);

  final AlertaRepository _repo;

  Future<Result<String>> call({
    required double latitud,
    required double longitud,
    double? precisionM,
  }) async {
    if (!latitud.isFinite ||
        !longitud.isFinite ||
        latitud < -90 ||
        latitud > 90 ||
        longitud < -180 ||
        longitud > 180) {
      return const Err<String>(
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
    );
  }
}
