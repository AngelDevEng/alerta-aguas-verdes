import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/async/guarda_respuestas.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/evidencia.dart';
import '../../domain/usecases/incidencia_usecases.dart';
import 'reportar_event.dart';
import 'reportar_state.dart';

/// ViewModel del reporte de incidencia.
///
/// Orquesta dos endpoints que no pueden ir en una sola llamada:
/// 1. `POST /incidencias` -> id.
/// 2. `POST /incidencias/:id/evidencias` -> una por foto.
///
/// El orden importa. Si las fotos fallan, el reporte ya esta guardado y hay que
/// informarlo como exito parcial; dar el proceso por fallido obligaria al
/// usuario a reenviar todo y crearia duplicados.
class ReportarBloc extends Bloc<ReportarEvent, ReportarState> {
  ReportarBloc(this._reportar, this._subirEvidencia)
      : super(const ReportarInicial()) {
    on<ReportarSolicitado>(_onSolicitado);
    on<ReintentarEvidencias>(_onReintentar);
    on<ReportarReiniciado>(_onReiniciado);
  }

  final ReportarIncidenciaUseCase _reportar;
  final SubirEvidenciaUseCase _subirEvidencia;

  /// Numero de envio en curso, para que un reintento no pise al anterior.
  final GuardaRespuestas _guarda = GuardaRespuestas();

  void _onReiniciado(ReportarReiniciado event, Emitter<ReportarState> emit) {
    // Rompe cualquier envio en vuelo antes de limpiar el estado.
    _guarda.invalidarTodo();
    emit(const ReportarInicial());
  }

  Future<void> _onSolicitado(
    ReportarSolicitado event,
    Emitter<ReportarState> emit,
  ) async {
    if (!event.datos.esValido) {
      emit(const ReportarError('Revisa el tipo y la ubicacion antes de enviar.'));
      return;
    }

    final generacion = _guarda.nuevoToken();
    emit(const ReportarEnviando(fase: FaseReporte.creando));

    final alta = await _reportar(event.datos);
    if (_guarda.estaVencido(generacion, isClosed: isClosed)) return;

    switch (alta) {
      case Err(:final failure):
        emit(ReportarError(failure.message));
      case Ok(:final value):
        await _subirFotos(
          emit,
          incidenciaId: value,
          evidencias: event.evidencias,
          yaSubidas: 0,
          generacion: generacion,
        );
    }
  }

  /// Reintenta **solo las fotos** del exito parcial.
  ///
  /// No vuelve a llamar a `POST /incidencias`: la incidencia ya existe y
  /// repetir el alta crearia un duplicado en la base y dos registros visibles
  /// para el operador.
  Future<void> _onReintentar(
    ReintentarEvidencias event,
    Emitter<ReportarState> emit,
  ) async {
    final previo = state;
    if (previo is! ReportarExito) return;
    if (previo.pendientes.isEmpty) return;

    final generacion = _guarda.nuevoToken();
    await _subirFotos(
      emit,
      incidenciaId: previo.incidenciaId,
      evidencias: previo.pendientes,
      yaSubidas: previo.fotosSubidas,
      generacion: generacion,
    );
  }

  Future<void> _subirFotos(
    Emitter<ReportarState> emit, {
    required String incidenciaId,
    required List<EvidenciaAdjunta> evidencias,
    required int yaSubidas,
    required int generacion,
  }) async {
    if (evidencias.isEmpty) {
      emit(ReportarExito(
        incidenciaId: incidenciaId,
        fotosSubidas: yaSubidas,
        fotosFallidas: 0,
      ));
      return;
    }

    var subidas = yaSubidas;
    final fallidas = <EvidenciaAdjunta>[];

    for (var i = 0; i < evidencias.length; i++) {
      // El progreso se pondera con un paso extra por el alta, para que la barra
      // no se quede clavada en 0 durante el POST y salte al final.
      emit(ReportarEnviando(
        fase: FaseReporte.subiendo,
        progreso: (i + 1) / (evidencias.length + 1),
      ));
      if (_guarda.estaVencido(generacion, isClosed: isClosed)) return;

      final r = await _subirEvidencia(incidenciaId, evidencias[i]);
      if (_guarda.estaVencido(generacion, isClosed: isClosed)) return;

      switch (r) {
        case Ok():
          subidas++;
        case Err():
          fallidas.add(evidencias[i]);
      }
    }

    emit(ReportarExito(
      incidenciaId: incidenciaId,
      fotosSubidas: subidas,
      fotosFallidas: fallidas.length,
      pendientes: fallidas,
    ));
  }

  @override
  Future<void> close() {
    // Corta cualquier subida en vuelo: si el usuario sale de la pantalla a
    // mitad del envio, el exito parcial ya no tiene quien lo vea.
    _guarda.invalidarTodo();
    return super.close();
  }
}
