import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/async/guarda_respuestas.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/detalle_incidencia.dart';
import '../../domain/usecases/incidencia_usecases.dart';
import 'incidencia_detalle_event.dart';
import 'incidencia_detalle_state.dart';

/// ViewModel del detalle de una incidencia y de sus acciones de despacho.
///
/// Cada `PATCH` devuelve el detalle completo desde el backend (`asignarUnidad` y
/// `cambiarEstado` terminan en `findOne`), asi que el exito se aplica sin volver
/// a pedir nada. Es el mismo detalle que el servidor acaba de commitir, no una
/// estimacion local: si la transaccion falla, no hay estado que mostrar.
/// Posicional y no con named parameters por una razon del lenguaje: el lint
/// `prefer_initializing_formals` pide `this._verDetalle`, pero Dart prohibe
/// parametros nombrados que empiecen con `_` (serian parte de la API publica de
/// la biblioteca). `IncidenciasBloc` resuelve lo mismo de esta forma.
class IncidenciaDetalleBloc extends Bloc<IncidenciaDetalleEvent, IncidenciaDetalleState> {
  IncidenciaDetalleBloc(
    this._verDetalle,
    this._cambiarEstado,
    this._asignarUnidad,
    this._id,
  ) : super(const DetalleInicial()) {
    on<DetalleSolicitado>(_onSolicitado);
    on<DetalleEstadoCambiado>(_onEstadoCambiado);
    on<DetalleUnidadAsignada>(_onUnidadAsignada);
    on<DetalleAvisoDescartado>(_onAvisoDescartado);
  }

  final ObtenerDetalleIncidenciaUseCase _verDetalle;
  final CambiarEstadoIncidenciaUseCase _cambiarEstado;
  final AsignarUnidadUseCase _asignarUnidad;

  /// Id de la incidencia que muestra esta pantalla. Viene del constructor y no
  /// de un evento porque la ruta ya lo conoce: hacerlo evento permitiria que una
  /// carga cambie de incidencia a mitad de camino.
  final String _id;

  final GuardaRespuestas _guarda = GuardaRespuestas();

  Future<void> _onSolicitado(
    DetalleSolicitado event,
    Emitter<IncidenciaDetalleState> emit,
  ) =>
      _cargar(emit);

  void _onAvisoDescartado(
    DetalleAvisoDescartado event,
    Emitter<IncidenciaDetalleState> emit,
  ) {
    // Vuelve al ultimo estado sano guardado, sin refetch: el detalle que se
    // acaba de intentar cambiar nunca llego a cambiar.
    if (state case DetalleAccionFallida(:final anterior)) emit(anterior);
  }

  Future<void> _cargar(Emitter<IncidenciaDetalleState> emit) async {
    final token = _guarda.nuevoToken();

    // El spinner solo tapa la pantalla si no hay nada que mostrar. Con detalle
    // cargado se recarga en silencio y la pantalla no parpadea.
    final previo = _cargadoActual()?.detalle;
    if (previo == null) emit(const DetalleCargando());

    final resultado = await _verDetalle(_id);
    if (_guarda.estaVencido(token, isClosed: isClosed)) return;

    switch (resultado) {
      case Ok(:final value):
        emit(DetalleCargado(value));
      case Err(:final failure):
        emit(DetalleError(failure));
    }
  }

  Future<void> _onEstadoCambiado(
    DetalleEstadoCambiado event,
    Emitter<IncidenciaDetalleState> emit,
  ) async {
    final actual = _cargadoActual();
    if (actual == null || actual.accionEnCurso) return;

    // Un estado que ya es el actual no se reenvia: el backend lo aceptaria y
    // agregaria una fila de historial identica, ensuciando la auditoria.
    if (actual.detalle.incidencia.estado == event.estado) return;

    await _accion(
      emit,
      () => _cambiarEstado(_id, event.estado),
      abrirBorradorSiFalla: false,
    );
  }

  Future<void> _onUnidadAsignada(
    DetalleUnidadAsignada event,
    Emitter<IncidenciaDetalleState> emit,
  ) async {
    final actual = _cargadoActual();
    if (actual == null || actual.accionEnCurso) return;

    if (event.unidadId.trim().isEmpty) return;

    // Cambiar de unidad no es un no-op: el backend pone la anterior de vuelta
    // en DISPONIBLE solo al cerrar el caso, no al reasignar. Se deja pasar y es
    // el servidor el que decide si puede.
    await _accion(
      emit,
      () => _asignarUnidad(_id, event.unidadId),
      // Si la unidad ya no esta disponible, el dialogo se reabre para elegir
      // otra: la falla mas probable en este flujo no merece perder lo que el
      // operador ya habia armado.
      abrirBorradorSiFalla: true,
    );
  }

  /// Logica compartida de los dos `PATCH`.
  Future<void> _accion(
    Emitter<IncidenciaDetalleState> emit,
    Future<Result<DetalleIncidencia>> Function() llamada, {
    required bool abrirBorradorSiFalla,
  }) async {
    final base = _cargadoActual();
    if (base == null) return;

    final token = _guarda.nuevoToken();
    emit(base.copyWith(accionEnCurso: true));

    final resultado = await llamada();
    if (_guarda.estaVencido(token, isClosed: isClosed)) return;

    switch (resultado) {
      case Ok(:final value):
        emit(DetalleCargado(value));
      case Err(:final failure):
        emit(DetalleAccionFallida(
          failure,
          anterior: base,
          // El dialogo de unidades se cierra solo si el fallo no es de asignar.
          mostrarBorrador: abrirBorradorSiFalla,
        ));
    }
  }

  /// Estado cargado actual, o null si todavia no hay nada que conservar.
  ///
  /// Tambien mira dentro de [DetalleAccionFallida]: despues de un fallo el
  /// operador tiene que poder reintentar sin cerrar la pantalla.
  /// Se copia el estado a una variable local porque un `switch (state)` con
  /// patron no refina el tipo de `state`, y el resultado saldria del tipo base.
  DetalleCargado? _cargadoActual() {
    final actual = state;
    return switch (actual) {
      DetalleCargado() => actual,
      DetalleAccionFallida(:final anterior) => anterior,
      _ => null,
    };
  }

  @override
  Future<void> close() {
    _guarda.invalidarTodo();
    return super.close();
  }
}