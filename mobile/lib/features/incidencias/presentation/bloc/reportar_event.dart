import 'package:equatable/equatable.dart';

import '../../domain/entities/evidencia.dart';
import '../../domain/entities/tipo_incidencia.dart';

/// Eventos del formulario de reporte.
sealed class ReportarEvent extends Equatable {
  const ReportarEvent();

  @override
  List<Object?> get props => const [];
}

/// Vuelve a la pantalla tras un exito, para poder reportar otra.
class ReportarReiniciado extends ReportarEvent {
  const ReportarReiniciado();
}

/// Envia el reporte.
///
/// [evidencias] va aparte de [datos] porque se suben despues del alta: el id
/// que devuelve `POST /incidencias` es el que necesita `POST
/// /incidencias/:id/evidencias`.
class ReportarSolicitado extends ReportarEvent {
  const ReportarSolicitado({required this.datos, this.evidencias = const []});

  final NuevaIncidencia datos;
  final List<EvidenciaAdjunta> evidencias;

  @override
  List<Object?> get props => [datos, evidencias];
}

/// El usuario tapped "reintentar" sobre un error de fotos parciales.
class ReintentarEvidencias extends ReportarEvent {
  const ReintentarEvidencias();
}
