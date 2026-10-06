import 'incidencia.dart';

/// Incidencia reducida a lo que el mapa necesita dibujar.
///
/// Viene de `GET /incidencias/geojson`, que expone solo `codigo`, `tipo`,
/// `estado`, `prioridad` y el punto (ver `v_incidencias_geojson` en
/// `database/02_indices_triggers.sql:71`). No es un subconjunto de [Incidencia]
/// reutilizable en la lista: la lista pagina y trae `id`, `ocurridoEn` y las
/// evidencias, y el mapa no.
///
/// Tampoco lleva `id`: el endpoint no lo devuelve, y un mapa no navega al
/// detalle. Si eso cambia, se agrega el campo aca y no se comparte la entidad
/// de la lista.
class IncidenciaMapa {
  const IncidenciaMapa({
    required this.codigo,
    required this.tipo,
    required this.estado,
    required this.prioridad,
    required this.latitud,
    required this.longitud,
  });

  /// Codigo corto del reporte (`INC-000123`).
  final String codigo;

  /// Nombre del tipo de incidencia (`Robo`, `Vialidad`...). El geojson trae el
  /// nombre, no el `tipoId`: no hay catalogo que resolver.
  final String tipo;

  final EstadoIncidencia estado;
  final Prioridad prioridad;

  final double latitud;
  final double longitud;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncidenciaMapa &&
          other.codigo == codigo &&
          other.latitud == latitud &&
          other.longitud == longitud &&
          other.estado == estado &&
          other.prioridad == prioridad;

  @override
  int get hashCode => Object.hash(codigo, estado, prioridad, latitud, longitud);

  @override
  String toString() => 'IncidenciaMapa($codigo, $prioridad)';
}
