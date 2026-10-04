import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/async/guarda_respuestas.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/incidencia.dart';
import '../../domain/repositories/incidencia_repository.dart';
import '../../domain/usecases/incidencia_usecases.dart';
import 'incidencias_event.dart';
import 'incidencias_state.dart';

/// ViewModel de la lista de incidencias.
class IncidenciasBloc extends Bloc<IncidenciasEvent, IncidenciasState> {
  IncidenciasBloc(this._listar, this._repo) : super(const IncidenciasInicial()) {
    on<CargarIncidencias>(_onCargar);
    on<AplicarFiltros>(_onAplicarFiltros);
    on<LimpiarFiltros>(_onLimpiarFiltros);
    on<CambiarPagina>(_onCambiarPagina);
  }

  final ListarIncidenciasUseCase _listar;

  /// Se usa para derivar el filtro por tipo, que no tiene endpoint propio.
  final IncidenciaRepository _repo;

  /// Descarta las respuestas de consultas que quedaron viejas.
  final GuardaRespuestas _guarda = GuardaRespuestas();

  Future<void> _onCargar(CargarIncidencias event, Emitter<IncidenciasState> emit) async {
    // Sin filtros explicitos se reutilizan los vigentes, para que el pull to
    // refresh no devuelva al usuario a la pagina 1.
    await _consultar(event.filtros ?? state.filtros, emit);
  }

  Future<void> _onAplicarFiltros(AplicarFiltros event, Emitter<IncidenciasState> emit) async {
    // `copyWith` ya reinicia la paginacion; no hace falta pedirlo aqui.
    final filtros = state.filtros.copyWith(
      estado: event.estado,
      tipoId: event.tipoId,
      desde: event.desde,
      hasta: event.hasta,
      limpiarEstado: event.limpiarEstado,
      limpiarTipo: event.limpiarTipo,
      limpiarDesde: event.limpiarDesde,
      limpiarHasta: event.limpiarHasta,
    );
    await _consultar(filtros, emit);
  }

  Future<void> _onLimpiarFiltros(LimpiarFiltros event, Emitter<IncidenciasState> emit) =>
      _consultar(const FiltrosIncidencia(), emit);

  Future<void> _onCambiarPagina(CambiarPagina event, Emitter<IncidenciasState> emit) async {
    final actual = state.filtros;
    if (event.pagina < 1 || event.pagina == actual.page) return;

    // Sin resultados cargados no hay a donde paginar.
    final previa = switch (state) {
      IncidenciasListas(:final pagina) => pagina,
      IncidenciasError(:final previo) => previo,
      _ => null,
    };
    if (event.pagina > (previa?.totalPaginas ?? 1)) return;

    await _consultar(actual.conPagina(event.pagina), emit);
  }

  /// Consulta compartida por todos los eventos de carga.
  Future<void> _consultar(FiltrosIncidencia filtros, Emitter<IncidenciasState> emit) async {
    final token = _guarda.nuevoToken();

    // Pagina visible antes de recargar, para no tapar la lista con un spinner.
    final previo = switch (state) {
      IncidenciasListas(:final pagina) => pagina,
      IncidenciasError(:final previo) => previo,
      IncidenciasCargando(:final previo) => previo,
      _ => null,
    };

    // Los tipos ya conocidos sobreviven a la recarga. Derivan de lo que se cargo
    // la ultima vez y no hay endpoint para pedirlos: si se perdieran al entrar
    // en estado de carga, el desplegable de tipo quedaria vacio hasta que
    // terminara la consulta.
    final tipos = state.tipos;

    emit(IncidenciasCargando(filtros: filtros, tipos: tipos, previo: previo));

    final resultado = await _listar(filtros);

    // Respuesta obsoleta o bloc ya cerrado: se descarta.
    if (_guarda.estaVencido(token, isClosed: isClosed)) return;

    switch (resultado) {
      case Ok(:final value):
        emit(IncidenciasListas(
          filtros: filtros,
          pagina: value,
          tipos: _repo
              .tiposDisponibles(
                value.items,
                previos: tipos.map((t) => TipoIncidenciaDisponible(id: t.id, nombre: t.nombre)).toList(),
              )
              .map((t) => TipoFiltro(id: t.id, nombre: t.nombre))
              .toList(),
        ));
      case Err(:final failure):
        emit(IncidenciasError(
          filtros: filtros,
          tipos: tipos,
          mensaje: failure.message,
          previo: previo,
        ));
    }
  }

  @override
  Future<void> close() {
    // Invalida lo que este en vuelo: si la pantalla se cierra a mitad de una
    // consulta, esa respuesta ya no tiene destino.
    _guarda.invalidarTodo();
    return super.close();
  }
}