import '../../../../core/error/result.dart';

/// Alertas de SOS (legacy `crearAlertaConToken`).
abstract interface class AlertaRepository {
  /// `POST /alertas` con la posicion del dispositivo.
  ///
  /// Devuelve el id de la alerta creada. El endpoint es publico a proposito
  /// (el ciudadano sin sesion tambien pulsa SOS), pero la peticion viaja con
  /// el token de sesion si lo hay, para que el backend la atribuya al
  /// reportante igual que el header `Authorization: Bearer` del legacy.
  Future<Result<String>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
  });
}
