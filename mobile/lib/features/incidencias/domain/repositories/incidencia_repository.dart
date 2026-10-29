import '../../../../core/error/result.dart';
import '../../domain/entities/detalle_incidencia.dart';
import '../../domain/entities/evidencia.dart';
import '../../domain/entities/incidencia.dart';
import '../../domain/entities/incidencia_mapa.dart';
import '../../domain/entities/tipo_incidencia.dart';

/// Contrato de persistencia de incidencias, definido en `domain/`.
///
/// La UI depende de esta interfaz, no de Dio ni del formato de la respuesta.
abstract interface class IncidenciaRepository {
  /// Lista paginada con filtros. Devuelve la pagina pedida, no un `Stream`: el
  /// backend no expone SSE ni websockets.
  Future<Result<PaginaIncidencias>> listar(FiltrosIncidencia filtros);

  /// Ultimas 1000 incidencias como puntos, para pintarlas en el mapa
  /// (`GET /incidencias/geojson`).
  ///
  /// A diferencia de [listar] no pagina ni filtra: el servidor corta en 1000 y
  /// el mapa las dibuja todas. Si un feature del `FeatureCollection` viene
  /// roto se descarta en el datasource, no aqui: un punto malformado no puede
  /// borrar el mapa entero.
  Future<Result<List<IncidenciaMapa>>> geojson();

  /// Detalle de una incidencia, con historial y evidencias.
  Future<Result<DetalleIncidencia>> obtenerDetalle(String id);

  /// Reporta una incidencia y devuelve el id que genero el servidor.
  Future<Result<String>> crear(NuevaIncidencia datos);

  /// Adjunta una foto a una incidencia ya creada.
  Future<Result<Evidencia>> subirEvidencia(
    String incidenciaId,
    EvidenciaAdjunta evidencia,
  );

  /// Avanza el estado de una incidencia y devuelve el detalle ya actualizado.
  Future<Result<DetalleIncidencia>> cambiarEstado(
    String id,
    EstadoIncidencia estado,
  );

  /// Despacha una unidad disponible. El backend pasa la incidencia a
  /// `DESPACHADA` y la unidad a `OCUPADA` en la misma transaccion.
  Future<Result<DetalleIncidencia>> asignarUnidad(String id, String unidadId);

  /// Tipos distintos presentes en las incidencias ya cargadas.
  ///
  /// Sirve para armar el filtro por tipo sin inventar ids: el backend no expone
  /// un catalogo de `tipos_incidencia`, y adivinar ids a mano se rompe en
  /// cuanto se agrega o reordena un tipo.
  ///
  /// [previos] se une al resultado. Hace falta porque el filtro se arma con lo
  /// que se cargo la ultima vez y cada pagina trae un subconjunto: al paginar
  /// o al filtrar por estado, una pagina puede no traer un tipo que la anterior
  /// si traia, y descartarlo dejaria una opcion en el desplegable que ya no
  /// devuelve nada. Si un id aparece en ambos, gana el nombre de [previos], para
  /// que el texto del chip y el del desplegable no puedan divergir.
  List<TipoIncidenciaDisponible> tiposDisponibles(
    List<Incidencia> cargadas, {
    List<TipoIncidenciaDisponible> previos = const [],
  });
}

/// Par de tipo que se puede seleccionar en el filtro.
class TipoIncidenciaDisponible {
  const TipoIncidenciaDisponible({required this.id, required this.nombre});

  final int id;
  final String nombre;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TipoIncidenciaDisponible && other.id == id && other.nombre == nombre;

  @override
  int get hashCode => Object.hash(id, nombre);

  @override
  String toString() => 'TipoIncidenciaDisponible($id, $nombre)';
}