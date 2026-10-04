import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../error/result.dart';

/// Posicion del dispositivo en el momento del reporte.
class PosicionActual {
  const PosicionActual({
    required this.latitud,
    required this.longitud,
    this.precisionMetros,
    this.altitud,
  });

  final double latitud;
  final double longitud;

  /// Radio de误差 en metros. Se muestra al usuario: reportar una ubicacion con
  /// 500 m de error sin decirlo lleva a que la unidad vaya a la calle de al
  /// lado.
  final double? precisionMetros;
  final double? altitud;

  /// Precision redondeada, para mostrarla sin ruido decimal.
  String get precisionLegible {
    final p = precisionMetros;
    if (p == null) return 'sin dato';
    if (p < 1000) return '${p.round()} m';
    return '${(p / 1000).toStringAsFixed(1)} km';
  }
}

/// Ubicacion del dispositivo.
///
/// Se inyecta en los BLoC en vez de llamar a `geolocator` desde un widget: asi
/// los tests pueden simular el GPS y la app no pide permisos a la vista.
class LocationService {
  const LocationService();

  /// Devuelve la posicion o un [Failure] explicando por que no pudo.
  ///
  /// Traduce los casos de geolocator a [LocalFailure] con un mensaje que el
  /// usuario pueda actuar ("activar GPS", "dar permiso"), en vez de dejar que
  /// la excepcion cruda llegue a la interfaz.
  Future<Result<PosicionActual>> posicionActual() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Err<PosicionActual>(
          LocalFailure('El GPS esta apagado. Activalo para ubicar la incidencia.'),
        );
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied) {
        return const Err<PosicionActual>(
          LocalFailure('Sin permiso de ubicacion. Activalo en Ajustes para reportar.'),
        );
      }
      if (permiso == LocationPermission.deniedForever) {
        return const Err<PosicionActual>(
          LocalFailure(
            'El permiso de ubicacion esta bloqueado. Habilitalo desde Ajustes.',
          ),
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // Precision de GPS de verdad: para reportar un hecho en la calle
          // conviene tardar un par de segundos a entregar 5 m en vez de 80.
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      return Ok<PosicionActual>(
        PosicionActual(
          latitud: pos.latitude,
          longitud: pos.longitude,
          precisionMetros: pos.accuracy,
          altitud: pos.altitude,
        ),
      );
    } on TimeoutException catch (e) {
      return Err<PosicionActual>(
        LocalFailure(
          'El GPS tardo demasiado en responder. Intenta de nuevo en un lugar '
          'mas despejado. (${e.message ?? 'sin detalle'})',
        ),
      );
    } catch (e) {
      return Err<PosicionActual>(
        LocalFailure('No se pudo obtener la ubicacion: $e'),
      );
    }
  }
}
