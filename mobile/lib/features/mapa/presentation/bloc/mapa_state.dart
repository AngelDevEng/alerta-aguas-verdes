import 'package:equatable/equatable.dart';

import '../../../../core/location/location_service.dart';
import '../../../incidencias/domain/entities/incidencia_mapa.dart';

/// Estados del mapa operativo.
sealed class MapaState extends Equatable {
  const MapaState();

  @override
  List<Object?> get props => const [];
}

/// Estado de arranque: el evento `CargarMapa` recien se emitio.
///
/// Existe para que el guard anti-doble-carga (`state is MapaCargando`) no
/// bloquee la primera carga, igual que `IncidenciasInicial` en la lista.
class MapaInicial extends MapaState {
  const MapaInicial();
}

/// Cargando la capa de incidencias y la posicion.
///
/// El mapa sigue visible debajo mientras se esta aca: tiles y el ultimo
/// estado se conservan, y solo cambian los marcadores al terminar.
class MapaCargando extends MapaState {
  const MapaCargando();
}

/// El mapa tiene datos.
class MapaListos extends MapaState {
  const MapaListos({
    required this.incidencias,
    this.miPosicion,
    this.aviso,
  });

  /// Puntos a dibujar. Vacia es un caso valido (aun no hay incidencias).
  final List<IncidenciaMapa> incidencias;

  /// Posicion del dispositivo, si el GPS respondio.
  ///
  /// `null` no es un error: el mapa se dibuja igual y [aviso] explica por que
  /// no esta la posicion propia.
  final PosicionActual? miPosicion;

  /// Fallo no bloqueante (normalmente el GPS) para mostrar un snackbar.
  ///
  /// No es un estado aparte a proposito: un GPS apagado no puede dejar el mapa
  /// sin incidencias.
  final String? aviso;

  MapaListos copyWith({PosicionActual? miPosicion, String? aviso, bool limpiarAviso = false}) =>
      MapaListos(
        incidencias: incidencias,
        miPosicion: miPosicion ?? this.miPosicion,
        aviso: limpiarAviso ? null : (aviso ?? this.aviso),
      );

  @override
  List<Object?> get props => [incidencias, miPosicion, aviso];
}

/// El servidor no respondio el geojson: sin eso no hay nada que dibujar.
///
/// La posicion del dispositivo no llega a este estado: un fallo de GPS deja
/// [MapaListos.aviso] en su lugar.
class MapaError extends MapaState {
  const MapaError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => [mensaje];
}
