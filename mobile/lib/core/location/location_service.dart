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
    this.degradada = false,
  });

  final double latitud;
  final double longitud;

  /// Radio de error en metros. Se muestra al usuario: reportar una ubicacion con
  /// 500 m de error sin decirlo lleva a que la unidad vaya a la calle de al
  /// lado.
  final double? precisionMetros;
  final double? altitud;

  /// True cuando la posicion viene de la ultima lectura conocida (no de un fix
  /// fresco) porque el GPS no respondio a tiempo. Menos precisa, pero mejor que
  /// no enviar nada.
  final bool degradada;

  /// Precision redondeada, para mostrarla sin ruido decimal.
  String get precisionLegible {
    final p = precisionMetros;
    if (p == null) return 'sin dato';
    if (p < 1000) return '${p.round()} m';
    return '${(p / 1000).toStringAsFixed(1)} km';
  }
}

/// Resultado de geolocalizacion ya traducido a un tipo propio.
class GpsFix {
  const GpsFix({
    required this.latitud,
    required this.longitud,
    this.precisionMetros,
    this.altitud,
  });

  final double latitud;
  final double longitud;
  final double? precisionMetros;
  final double? altitud;
}

/// Permiso de ubicacion, sin depender del enum de geolocator (para tests).
enum PermisoUbicacion { permitido, denegado, denegadoSiempre }

/// Abstraccion de geolocator.
///
/// Existe para que los tests puedan simular GPS sin el plugin: la logica de
/// "timeout -> ultima conocida" se prueba con un doble, no con un dispositivo.
abstract interface class GeolocatorApi {
  Future<bool> estaActivo();
  Future<PermisoUbicacion> permiso();
  Future<PermisoUbicacion> pedirPermiso();
  Future<void> abrirAjustes();

  /// Fix fresco. Debe lanzar [TimeoutException] si [tiempoLimite] se agota.
  Future<GpsFix> posicionActual({required Duration tiempoLimite});

  /// Ultima posicion conocida, o null si no hay ninguna cacheada.
  Future<GpsFix?> ultimaConocida();
}

/// Implementacion real sobre el plugin `geolocator`.
class GeolocatorReal implements GeolocatorApi {
  const GeolocatorReal();

  @override
  Future<bool> estaActivo() => Geolocator.isLocationServiceEnabled();

  @override
  Future<PermisoUbicacion> permiso() async => _mapear(await Geolocator.checkPermission());

  @override
  Future<PermisoUbicacion> pedirPermiso() async => _mapear(await Geolocator.requestPermission());

  @override
  Future<void> abrirAjustes() async {
    await Geolocator.openAppSettings();
  }

  @override
  Future<GpsFix> posicionActual({required Duration tiempoLimite}) async {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: tiempoLimite,
      ),
    );
    return _fix(pos);
  }

  @override
  Future<GpsFix?> ultimaConocida() async {
    final pos = await Geolocator.getLastKnownPosition();
    return pos == null ? null : _fix(pos);
  }

  static PermisoUbicacion _mapear(LocationPermission permiso) => switch (permiso) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          PermisoUbicacion.permitido,
        LocationPermission.deniedForever => PermisoUbicacion.denegadoSiempre,
        _ => PermisoUbicacion.denegado,
      };

  static GpsFix _fix(Position pos) => GpsFix(
        latitud: pos.latitude,
        longitud: pos.longitude,
        precisionMetros: pos.accuracy,
        altitud: pos.altitude,
      );
}

/// Ubicacion del dispositivo.
///
/// Se inyecta en los BLoC en vez de llamar a `geolocator` desde un widget: asi
/// los tests pueden simular el GPS y la app no pide permisos a la vista.
class LocationService {
  LocationService({GeolocatorApi? api}) : _api = api ?? const GeolocatorReal();

  final GeolocatorApi _api;

  /// Fix fresco con `timeLimit` corto (5s). Si el GPS no responde a tiempo se
  /// usa la ultima posicion conocida (`degradada: true`); si tampoco hay, se
  /// devuelve un [Failure] y el llamador decide (el SOS igualmente se envia
  /// marcado como "sin ubicacion").
  Future<Result<PosicionActual>> posicionActual() async {
    try {
      if (!await _api.estaActivo()) {
        return const Err<PosicionActual>(
          LocalFailure('El GPS esta apagado. Activalo para ubicar la incidencia.'),
        );
      }

      var permiso = await _api.permiso();
      if (permiso == PermisoUbicacion.denegado) {
        permiso = await _api.pedirPermiso();
      }
      if (permiso == PermisoUbicacion.denegadoSiempre) {
        await _api.abrirAjustes();
        return const Err<PosicionActual>(
          LocalFailure(
            'El permiso de ubicacion esta bloqueado. Habilitalo desde Ajustes.',
          ),
        );
      }
      if (permiso == PermisoUbicacion.denegado) {
        return const Err<PosicionActual>(
          LocalFailure('Sin permiso de ubicacion. Activalo en Ajustes para reportar.'),
        );
      }

      GpsFix fix;
      var degradada = false;
      try {
        fix = await _api.posicionActual(tiempoLimite: const Duration(seconds: 5));
      } on TimeoutException {
        // Sin fix fresco: se recurre a la ultima lectura conocida.
        final ultima = await _api.ultimaConocida();
        if (ultima == null) {
          return const Err<PosicionActual>(
            LocalFailure(
              'El GPS tardo demasiado y no hay una ubicacion previa. Reintenta '
              'en un lugar mas despejado.',
            ),
          );
        }
        fix = ultima;
        degradada = true;
      }

      return Ok<PosicionActual>(
        PosicionActual(
          latitud: fix.latitud,
          longitud: fix.longitud,
          precisionMetros: fix.precisionMetros,
          altitud: fix.altitud,
          degradada: degradada,
        ),
      );
    } catch (e) {
      return Err<PosicionActual>(
        LocalFailure('No se pudo obtener la ubicacion: $e'),
      );
    }
  }
}