import 'package:equatable/equatable.dart';

import '../../domain/entities/evidencia.dart';

/// Estados del formulario de reporte.
sealed class ReportarState extends Equatable {
  const ReportarState();

  @override
  List<Object?> get props => const [];
}

/// Sin nada enviado. Estado de arranque y de retorno desde el exito.
class ReportarInicial extends ReportarState {
  const ReportarInicial();
}

/// Enviando.
///
/// [progreso] va de 0 a 1 e incluye el alta, que se pondera igual que cada
/// foto: asi la barra avanza siempre, en vez de quedarse en 0 durante todo el
/// `POST /incidencias` y saltar al final.
class ReportarEnviando extends ReportarState {
  const ReportarEnviando({required this.fase, this.progreso = 0});

  final FaseReporte fase;
  final double progreso;

  @override
  List<Object?> get props => [fase, progreso];
}

/// Que parte del envio va.
enum FaseReporte {
  /// Creando la incidencia: sin fotos todavia.
  creando('Guardando el reporte'),

  /// Subiendo las fotos una por una.
  subiendo('Subiendo fotos');

  const FaseReporte(this.etiqueta);
  final String etiqueta;
}

/// Reporte guardado.
///
/// [fotosFallidas] distingue los dos finales posibles: si el reporte se guardo
/// pero las fotos no, el exito es real y hay que decirlo sin taparlo. Es el caso
/// de un `CIUDADANO`, que puede reportar pero no adjuntar evidencia.
class ReportarExito extends ReportarState {
  const ReportarExito({
    required this.incidenciaId,
    required this.fotosSubidas,
    required this.fotosFallidas,
    this.pendientes = const [],
  });

  final String incidenciaId;
  final int fotosSubidas;

  /// Fotos que quedaron sin subir. Vacio en el exito limpio.
  final int fotosFallidas;

  /// Las que faltaron, para poder reintentarlas sin volver a pedir la foto.
  final List<EvidenciaAdjunta> pendientes;

  /// El reporte se guardo aunque alguna foto haya fallado.
  bool get parcial => fotosFallidas > 0;

  @override
  List<Object?> get props => [incidenciaId, fotosSubidas, fotosFallidas, pendientes];
}

/// El reporte NO se guardo. Se puede reintentar el envio completo.
class ReportarError extends ReportarState {
  const ReportarError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => [mensaje];
}
