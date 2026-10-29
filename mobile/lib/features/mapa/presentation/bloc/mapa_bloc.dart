import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../../../core/location/location_service.dart';
import '../../../incidencias/domain/usecases/incidencia_usecases.dart';
import 'mapa_event.dart';
import 'mapa_state.dart';

/// Datos del mapa operativo.
///
/// Compone dos lecturas independientes en un solo estado:
///
/// - `GET /incidencias/geojson` para los marcadores (sin eso no hay mapa),
/// - la posicion del dispositivo, para centrar y mostrar el "yo".
///
/// Van en paralelo a proposito: el GPS puede tardar hasta 20 s en una calle
/// con mala senal, y esperarlo antes de pedir el geojson dejaria el mapa vacio
/// mucho tiempo.
class MapaBloc extends Bloc<MapaEvent, MapaState> {
  MapaBloc(this._obtenerIncidencias, this._location)
      : super(const MapaInicial()) {
    on<CargarMapa>(_onCargar);
    on<CentrarEnMi>(_onCentrar);
  }

  final ObtenerIncidenciasMapaUseCase _obtenerIncidencias;
  final LocationService _location;

  Future<void> _onCargar(CargarMapa event, Emitter<MapaState> emit) async {
    // Guard anti-doble-carga: el transformer por defecto de bloc es concurrent
    // (flatMap en `bloc.dart:61`), asi que un segundo toque de recarga entra
    // mientras la primera sigue en vuelo.
    if (state is MapaCargando) return;

    emit(const MapaCargando());

    // Los dos futuros arrancan juntos y se esperan despues: que el GPS siga
    // buscando no frena la capa del mapa.
    final geojson = _obtenerIncidencias();
    final posicion = _location.posicionActual();
    final geojsonRes = await geojson;
    final posicionRes = await posicion;
    if (isClosed) return;

    switch (geojsonRes) {
      case Err(:final failure):
        // Sin capa de incidencias no hay mapa util: la pantalla ofrece
        // reintento. El GPS no cambia eso.
        emit(MapaError(failure.message));
      case Ok(value: final incidencias):
        // Un GPS que falla no vacia el mapa: queda sin posicion propia y el
        // aviso explica por que.
        final (miPosicion, aviso) = switch (posicionRes) {
          Ok(value: final pos) => (pos, null),
          Err(failure: final f) => (null, f.message),
        };
        emit(
          MapaListos(
            incidencias: incidencias,
            miPosicion: miPosicion,
            aviso: aviso,
          ),
        );
    }
  }

  Future<void> _onCentrar(CentrarEnMi event, Emitter<MapaState> emit) async {
    // Sin mapa cargado todavia no hay donde centrar, y una carga en curso ya
    // va a traer la posicion.
    if (state is! MapaListos) return;

    final res = await _location.posicionActual();
    if (isClosed) return;

    // La recarga puede haber corrido mientras esperabamos el GPS: se trabaja
    // sobre el estado actual, no sobre el capturado antes del await.
    final actual = state;
    if (actual is! MapaListos) return;

    switch (res) {
      case Ok(:final value):
        emit(actual.copyWith(miPosicion: value, limpiarAviso: true));
      case Err(:final failure):
        // El aviso reemplaza al anterior: repetir el mismo texto no aporta.
        emit(actual.copyWith(aviso: failure.message));
    }
  }
}
