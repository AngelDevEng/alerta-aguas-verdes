import 'evidencia.dart';
import 'incidencia.dart';

/// Detalle de una incidencia: la fila de `SELECT_BASE` mas lo que solo trae
/// `GET /incidencias/:id`.
///
/// Se modela por composicion y no agregando campos opcionales a [Incidencia]
/// porque son dos respuestas distintas del servidor. Si el detalle se
/// mezclara en la entidad de la lista, cada fila paginada arrastraria dos
/// listas vacias y el modelo de la lista dejaria de reflejar lo que devuelve
/// su endpoint.
class DetalleIncidencia {
  const DetalleIncidencia({
    required this.incidencia,
    required this.historial,
    required this.evidencias,
  });

  final Incidencia incidencia;

  /// Movimientos de estado, del mas antiguo al mas reciente.
  final List<MovimientoEstado> historial;

  /// Evidencias adjuntas, ordenadas por `capturado_en`.
  final List<Evidencia> evidencias;

  /// Detalle recien atualizado sin tocar historial ni evidencias.
  ///
  /// Lo usan `cambiarEstado` y `asignarUnidad`, que devuelven un `findOne`
  /// completo pero en la app solo interesa que cambie la incidencia. Aplazar
  /// el refetch del historial evita el parpadeo de las dos listas mientras la
  /// peticion de cambio de estado vuelve.
  DetalleIncidencia conIncidencia(Incidencia nueva) => DetalleIncidencia(
        incidencia: nueva,
        historial: historial,
        evidencias: evidencias,
      );

  bool get tieneEvidencias => evidencias.isNotEmpty;
  bool get tieneHistorial => historial.isNotEmpty;
}

/// Un cambio de estado registrado en `historial_incidencia`.
///
/// El backend lo agrega solo: `cambiarEstado` y `asignarUnidad` insertan la
/// fila dentro de la misma transaccion. Por eso aca no hay forma de crear un
/// movimiento desde la app, y `usuario` puede venir null si la BD no lo asocio.
class MovimientoEstado {
  const MovimientoEstado({
    required this.estadoAnterior,
    required this.estadoNuevo,
    required this.registradoEn,
    this.usuario,
  });

  final EstadoIncidencia estadoAnterior;
  final EstadoIncidencia estadoNuevo;
  final DateTime registradoEn;

  /// Nombre completo de quien hizo el cambio, si el backend lo pudo resolver.
  final String? usuario;

  /// `true` cuando el registro es el alta inicial, que la BD crea sin estado
  /// anterior. Se distingue porque en la UI es el punto de partida del caso y
  /// no una transicion mas.
  bool get esAlta =>
      estadoAnterior == EstadoIncidencia.unknown &&
      estadoNuevo == EstadoIncidencia.registrada;

  /// Texto de una linea para el `ListTile` del historial.
  String get resumen => esAlta
      ? 'Incidencia registrada'
      : '${estadoAnterior.etiqueta} → ${estadoNuevo.etiqueta}';

  String get autor => usuario?.trim().isNotEmpty == true ? usuario!.trim() : 'Sistema';

  @override
  String toString() => 'MovimientoEstado($resumen, $registradoEn, $autor)';
}