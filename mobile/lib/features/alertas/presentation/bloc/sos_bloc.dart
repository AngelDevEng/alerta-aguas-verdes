import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../../../core/location/location_service.dart';
import '../../domain/usecases/alerta_usecases.dart';
import 'sos_event.dart';
import 'sos_state.dart';

/// ViewModel del boton SOS.
///
/// Orquesta los dos pasos que el legacy repartia entre `MenuActivity` (GPS) y
/// `SerenazgoRepository.crearAlertaConToken` (HTTP):
///
/// 1. posicion del dispositivo via [LocationService] (permisos resueltos ahi),
/// 2. `POST /alertas`.
///
/// El exito muestra "Auxilio enviado a central" y el fallo el mensaje del
/// [Failure]. El legacy ademas abria `RastreoActivity` (rol CIUDADANO) tras
/// el exito; esa navegacion queda para 4d.4 (rastreo).
class SosBloc extends Bloc<SosEvent, SosState> {
  SosBloc(this._location, this._enviar) : super(const SosInicial()) {
    on<SosSolicitado>(_onSolicitado);
  }

  final LocationService _location;
  final EnviarSosUseCase _enviar;

  Future<void> _onSolicitado(
    SosSolicitado event,
    Emitter<SosState> emit,
  ) async {
    // Guarda anti doble tap. El transformer por defecto de bloc es concurrent
    // (flatMap en `bloc.dart:61`), asi que un segundo evento entra mientras el
    // primero sigue en vuelo y ve [SosEnviando]. Sin esto, dos toques
    // rapidos crearian dos alertas CRITICAS duplicadas en operaciones.
    if (state is SosEnviando) return;

    emit(const SosEnviando());

    final posicion = await _location.posicionActual();
    if (isClosed) return;

    switch (posicion) {
      case Err(:final failure):
        emit(SosError(failure.message));
        return;
      case Ok(:final value):
        final r = await _enviar(
          latitud: value.latitud,
          longitud: value.longitud,
          precisionM: value.precisionMetros,
        );
        if (isClosed) return;

        switch (r) {
          case Err(:final failure):
            emit(SosError(failure.message));
          case Ok():
            emit(const SosEnviado());
        }
    }
  }
}
