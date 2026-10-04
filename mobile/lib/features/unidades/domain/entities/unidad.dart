/// Tipo de unidad de serenazgo. Espejo de `TIPOS_UNIDAD` en
/// `backend/src/common/enums.ts`.
enum TipoUnidad {
  patrulla('PATRULLA', 'Patrulla'),
  motocicleta('MOTOCICLETA', 'Motocicleta'),
  pie('PIE', 'A pie'),
  unknown('', 'Desconocido');

  const TipoUnidad(this.wire, this.etiqueta);

  final String wire;
  final String etiqueta;

  static TipoUnidad fromWire(String? raw) {
    if (raw == null) return TipoUnidad.unknown;
    final normalizado = raw.trim().toUpperCase();
    for (final t in TipoUnidad.values) {
      if (t.wire == normalizado) return t;
    }
    return TipoUnidad.unknown;
  }
}

/// Estado operativo de una unidad. Espejo de `ESTADOS_UNIDAD`.
enum EstadoUnidad {
  disponible('DISPONIBLE', 'Disponible'),
  ocupada('OCUPADA', 'Ocupada'),
  fueraDeServicio('FUERA_SERVICIO', 'Fuera de servicio'),
  unknown('', 'Desconocido');

  const EstadoUnidad(this.wire, this.etiqueta);

  final String wire;
  final String etiqueta;

  static EstadoUnidad fromWire(String? raw) {
    if (raw == null) return EstadoUnidad.unknown;
    final normalizado = raw.trim().toUpperCase();
    for (final e in EstadoUnidad.values) {
      if (e.wire == normalizado) return e;
    }
    return EstadoUnidad.unknown;
  }

  /// Si se puede asignar a una incidencia.
  ///
  /// No es una regla inventada: `asignarUnidad` en `unidades.service.ts` toma
  /// `FOR UPDATE` sobre la fila y tira `BadRequestException` si el estado no es
  /// `DISPONIBLE`. Filtrar aca evita ofrecer al operador una opcion que el
  /// servidor va a rechazar.
  bool get asignable => this == EstadoUnidad.disponible;
}

/// Unidad de serenazgo (patrullero, motocicleta o pie).
///
/// La entidad no tiene un campo `nombre`: `SELECT_BASE` en
/// `unidades.service.ts` solo expone `codigo`, `tipo` y `placa`, que es lo que
/// identifica a la unidad en la operacion real. [etiquetaOperador] arma el texto
/// que ve el operador sin inventar un nombre que la base no tiene.
class Unidad {
  const Unidad({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.estado,
    this.placa,
    this.responsableId,
    this.latitud,
    this.longitud,
    this.ultimaActualizacion,
  });

  final String id;
  final String codigo;
  final TipoUnidad tipo;
  final EstadoUnidad estado;

  /// Patente. Opcional: no todas las unidades la tienen (`PIE` no).
  final String? placa;

  /// Usuario sereno responsable. Opcional si la unidad esta sin asignar.
  final String? responsableId;

  /// Ultima posicion conocida. Puede venir null si la unidad nunca reporto.
  final double? latitud;
  final double? longitud;
  final DateTime? ultimaActualizacion;

  /// `true` si la unidad alguna vez reporto su posicion.
  bool get tienePosicion => latitud != null && longitud != null;

  /// `codigo` + `placa` cuando existe: lo unico que identifica a la unidad.
  String get etiquetaOperador {
    final p = placa?.trim();
    return p == null || p.isEmpty ? codigo : '$codigo · $p';
  }
}

/// Unidad cercana, tal como la devuelve `GET /unidades/cercanas`.
///
/// Proyeccion mas chica que [Unidad]: la funcion `fn_unidades_cercanas` del
/// backend devuelve solo `id, codigo, tipo, distanciaM`. Modelar esto como
/// [Unidad] obligaria a inventar `placa`, `estado` y `responsableId`.
class UnidadCercana {
  const UnidadCercana({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.distanciaM,
  });

  final String id;
  final String codigo;
  final TipoUnidad tipo;

  /// Distancia en metros desde el punto de consulta.
  final double distanciaM;

  /// Distancia legible: menos de 1 km en metros, si no en kilometros.
  String get distanciaTexto => distanciaM < 1000
      ? '${distanciaM.round()} m'
      : '${(distanciaM / 1000).toStringAsFixed(1)} km';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnidadCercana && other.id == id && other.distanciaM == distanciaM;

  @override
  int get hashCode => Object.hash(id, distanciaM);

  @override
  String toString() => 'UnidadCercana($codigo, $distanciaTexto)';
}