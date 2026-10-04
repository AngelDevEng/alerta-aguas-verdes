/// Estados posibles de una incidencia.
///
/// Espejo de `ESTADOS_INCIDENCIA` en `backend/src/common/enums.ts`. Si el
/// backend agrega un estado, el [unknown] evita que la app falle al parsear.
enum EstadoIncidencia {
  registrada('REGISTRADA', 'Registrada'),
  despachada('DESPACHADA', 'Despachada'),
  enAtencion('EN_ATENCION', 'En atención'),
  atendida('ATENDIDA', 'Atendida'),
  cancelada('CANCELADA', 'Cancelada'),
  unknown('', 'Desconocido');

  const EstadoIncidencia(this.wire, this.etiqueta);

  /// Valor exacto que viaja por la API.
  final String wire;

  /// Texto para mostrar en la UI.
  final String etiqueta;

  static EstadoIncidencia fromWire(String? raw) {
    if (raw == null) return EstadoIncidencia.unknown;
    final normalizado = raw.trim().toUpperCase();
    for (final e in EstadoIncidencia.values) {
      if (e.wire == normalizado) return e;
    }
    return EstadoIncidencia.unknown;
  }

  bool get esAbierta =>
      this == EstadoIncidencia.registrada ||
      this == EstadoIncidencia.despachada ||
      this == EstadoIncidencia.enAtencion;

  /// Si el caso ya no admite despacho.
  bool get esCerrado =>
      this == EstadoIncidencia.atendida || this == EstadoIncidencia.cancelada;
}

/// Estados que la UI ofrece para avanzar una incidencia.
///
/// Son una guia de uso, no una regla del servidor: `CambiarEstadoDto` solo
/// valida `@IsIn(ESTADOS_INCIDENCIA)`, asi que el backend aceptaria cualquier
/// salto. Esta lista sale de leer el flujo real de `incidencias.service.ts`:
///
/// - [EstadoIncidencia.enAtencion] y [EstadoIncidencia.cancelada] son
///   alcanzables desde una incidencia recien registrada.
/// - [EstadoIncidencia.despachada] solo tiene sentido con unidad asignada, pero
///   se ofrece igual porque el operador puede marcar el despacho a mano.
/// - Cerrada no se abre: reabrir es una operacion de supervision y no esta
///   expuesta. Prefiero que la UI no ofrezca algo que el backend aceptaria sin
///   auditar.
///
/// Cuando el backend aprenda a rechazar transiciones invalidas, esta lista pasa
/// a ser el espejo de esa regla y el resto de la app no cambia.
extension DespachoSobreEstado on EstadoIncidencia {
  List<EstadoIncidencia> get siguientesPosibles => switch (this) {
        EstadoIncidencia.registrada => const [
            EstadoIncidencia.despachada,
            EstadoIncidencia.enAtencion,
            EstadoIncidencia.cancelada,
          ],
        EstadoIncidencia.despachada => const [
            EstadoIncidencia.enAtencion,
            EstadoIncidencia.atendida,
            EstadoIncidencia.cancelada,
          ],
        EstadoIncidencia.enAtencion => const [
            EstadoIncidencia.atendida,
            EstadoIncidencia.cancelada,
          ],
        EstadoIncidencia.atendida ||
        EstadoIncidencia.cancelada ||
        EstadoIncidencia.unknown =>
          const <EstadoIncidencia>[],
      };
}

/// Prioridad de la incidencia. Espejo de `prioridad_nivel`.
enum Prioridad {
  baja('BAJA', 'Baja'),
  media('MEDIA', 'Media'),
  alta('ALTA', 'Alta'),
  critica('CRITICA', 'Crítica'),
  unknown('', 'Desconocida');

  const Prioridad(this.wire, this.etiqueta);

  final String wire;
  final String etiqueta;

  static Prioridad fromWire(String? raw) {
    if (raw == null) return Prioridad.unknown;
    final normalizado = raw.trim().toUpperCase();
    for (final p in Prioridad.values) {
      if (p.wire == normalizado) return p;
    }
    return Prioridad.unknown;
  }
}

/// Entidad de dominio: una incidencia reportada.
///
/// No conoce el transporte ni el paginado: eso vive en el repositorio. Aqui
/// solo hay hechos del negocio mas lo derivado que la UI necesita (por ejemplo
/// [estaCerrada]) y que conviene calcular una sola vez.
class Incidencia {
  const Incidencia({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.tipoId,
    required this.estado,
    required this.prioridad,
    required this.latitud,
    required this.longitud,
    required this.ocurridoEn,
    required this.evidencias,
    this.descripcion,
    this.referencia,
    this.unidadAsignadaId,
    this.reportadoPor,
    this.reportadoPorNombre,
    this.atendidoEn,
  });

  final String id;

  /// Codigo corto que se muestra al usuario (por ejemplo `INC-000123`).
  final String codigo;

  final String tipo;
  final int tipoId;
  final EstadoIncidencia estado;
  final Prioridad prioridad;

  final double latitud;
  final double longitud;

  final DateTime ocurridoEn;

  /// Cantidad de evidencias adjuntas. El detalle llega en `GET /incidencias/:id`.
  final int evidencias;

  final String? descripcion;

  /// Referencia opcional del reporte (patente, numero de expediente...).
  final String? referencia;

  final String? unidadAsignadaId;
  final String? reportadoPor;
  final String? reportadoPorNombre;
  final DateTime? atendidoEn;

  bool get estaCerrada =>
      estado == EstadoIncidencia.atendida || estado == EstadoIncidencia.cancelada;

  /// Si ya tiene unidad en camino o trabajando.
  bool get fueDespachada => estado == EstadoIncidencia.despachada || estado == EstadoIncidencia.enAtencion;
}

/// Resultado paginado de `GET /incidencias`.
class PaginaIncidencias {
  const PaginaIncidencias({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  const PaginaIncidencias.vacia()
      : items = const [],
        total = 0,
        page = 1,
        limit = 20;

  final List<Incidencia> items;
  final int total;
  final int page;
  final int limit;

  /// Minimo 1: con cero resultados hay una pagina vacia, no cero paginas.
  /// Asi los controles de paginacion comparan siempre contra algo valido.
  int get totalPaginas => limit <= 0 ? 1 : (total / limit).ceil().clamp(1, 1 << 31);

  bool get haySiguiente => page < totalPaginas;
  bool get hayAnterior => page > 1;

  PaginaIncidencias copyWith({List<Incidencia>? items, int? total, int? page}) =>
      PaginaIncidencias(
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        limit: limit,
      );
}

/// Filtros de la lista, con paginacion.
///
/// Viaja como objeto para que el BLoC pueda comparar si cambio algo y decidir
/// si conviene recargar. [page] arranca en 1 porque el backend lo exige asi
/// (`@Min(1)`).
class FiltrosIncidencia {
  const FiltrosIncidencia({
    this.estado,
    this.tipoId,
    this.desde,
    this.hasta,
    this.page = 1,
    this.limit = 20,
  });

  final EstadoIncidencia? estado;
  final int? tipoId;
  final DateTime? desde;
  final DateTime? hasta;
  final int page;
  final int limit;

  /// Traduce a query string, omitiendo lo no informado.
  ///
  /// Las fechas van en ISO-8601 porque el DTO del backend usa `@IsDateString()`.
  Map<String, dynamic> toQuery() => <String, dynamic>{
        if (estado != null && estado != EstadoIncidencia.unknown)
          'estado': estado!.wire,
        if (tipoId != null) 'tipoId': tipoId,
        if (desde != null) 'desde': desde!.toUtc().toIso8601String(),
        if (hasta != null) 'hasta': hasta!.toUtc().toIso8601String(),
        'page': page,
        'limit': limit,
      };

  /// Cambia uno o mas filtros y **vuelve siempre a la pagina 1**.
  ///
  /// Que el reset viva aqui y no en el BLoC es a proposito: filtrar con la
  /// pagina 5 abierta deja la pantalla vacia y parece un fallo. Haciendo que
  /// el reset sea estructural, ningun call site puede olvidarlo. Para cambiar
  /// solo de pagina esta [conPagina], no esta.
  FiltrosIncidencia copyWith({
    EstadoIncidencia? estado,
    int? tipoId,
    DateTime? desde,
    DateTime? hasta,
    int? limit,
    bool limpiarEstado = false,
    bool limpiarTipo = false,
    bool limpiarDesde = false,
    bool limpiarHasta = false,
  }) =>
      FiltrosIncidencia(
        estado: limpiarEstado ? null : (estado ?? this.estado),
        tipoId: limpiarTipo ? null : (tipoId ?? this.tipoId),
        desde: limpiarDesde ? null : (desde ?? this.desde),
        hasta: limpiarHasta ? null : (hasta ?? this.hasta),
        page: 1,
        limit: limit ?? this.limit,
      );

  /// Cambia solo la pagina, conservando los filtros.
  FiltrosIncidencia conPagina(int pagina) => FiltrosIncidencia(
        estado: estado,
        tipoId: tipoId,
        desde: desde,
        hasta: hasta,
        page: pagina,
        limit: limit,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiltrosIncidencia &&
          other.estado == estado &&
          other.tipoId == tipoId &&
          other.desde == desde &&
          other.hasta == hasta &&
          other.page == page &&
          other.limit == limit;

  @override
  int get hashCode => Object.hash(estado, tipoId, desde, hasta, page, limit);

  @override
  String toString() => 'FiltrosIncidencia($estado, tipo:$tipoId, page:$page/$limit)';
}