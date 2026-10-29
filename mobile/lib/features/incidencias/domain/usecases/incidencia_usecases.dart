import '../../../../core/error/result.dart';
import '../../domain/entities/detalle_incidencia.dart';
import '../../domain/entities/evidencia.dart';
import '../../domain/entities/incidencia.dart';
import '../../domain/entities/incidencia_mapa.dart';
import '../../domain/entities/tipo_incidencia.dart';
import '../../domain/repositories/incidencia_repository.dart';

/// Carga una pagina de incidencias con los filtros indicados.
///
/// Trivial a proposito: fija la frontera entre BLoC y repositorio para que
/// cambiar la regla de cache (por ejemplo, guardar la ultima pagina para
/// pintar de inmediato sin conexion) se resuelva en un solo lugar.
class ListarIncidenciasUseCase {
  const ListarIncidenciasUseCase(this._repo);

  final IncidenciaRepository _repo;

  Future<Result<PaginaIncidencias>> call(FiltrosIncidencia filtros) =>
      _repo.listar(filtros);
}

/// Carga el detalle de una incidencia con su historial y sus evidencias.
class ObtenerDetalleIncidenciaUseCase {
  const ObtenerDetalleIncidenciaUseCase(this._repo);

  final IncidenciaRepository _repo;

  Future<Result<DetalleIncidencia>> call(String id) => _repo.obtenerDetalle(id);
}

/// Reporta una incidencia.
///
/// A proposito no sube las fotos: el alta y las evidencias van en endpoints
/// distintos con permisos distintos, asi que un fallo al adjuntar una foto no
/// puede hacer perder el reporte. El orden de operaciones vive en
/// `ReportarIncidenciaBloc`.
class ReportarIncidenciaUseCase {
  const ReportarIncidenciaUseCase(this._repo);

  final IncidenciaRepository _repo;

  Future<Result<String>> call(NuevaIncidencia datos) => _repo.crear(datos);
}

/// Adjunta una foto a una incidencia recien creada.
class SubirEvidenciaUseCase {
  const SubirEvidenciaUseCase(this._repo);

  final IncidenciaRepository _repo;

  Future<Result<Evidencia>> call(String incidenciaId, EvidenciaAdjunta evidencia) =>
      _repo.subirEvidencia(incidenciaId, evidencia);
}

/// Avanza el estado de una incidencia.
///
/// No valida la transicion: `DespachoSobreEstado.siguientesPosibles` es una guia
/// de UI y el backend solo exige que el estado exista en el enum. Validar aca
/// crearia una segunda copia de la regla que el servidor no tiene, y el dia que
/// el servidor la aprenda las dos divergen.
class CambiarEstadoIncidenciaUseCase {
  const CambiarEstadoIncidenciaUseCase(this._repo);

  final IncidenciaRepository _repo;

  Future<Result<DetalleIncidencia>> call(String id, EstadoIncidencia estado) =>
      _repo.cambiarEstado(id, estado);
}

/// Despacha una unidad disponible a la incidencia.
///
/// El backend exige que la unidad este `DISPONIBLE` y la pasa a `OCUPADA` en la
/// misma transaccion, junto con el estado `DESPACHADA` de la incidencia.
class AsignarUnidadUseCase {
  const AsignarUnidadUseCase(this._repo);

  final IncidenciaRepository _repo;

  Future<Result<DetalleIncidencia>> call(String id, String unidadId) =>
      _repo.asignarUnidad(id, unidadId);
}

/// Puntos de incidencias para pintar en el mapa (`GET /incidencias/geojson`).
///
/// No pagina ni filtra como [ListarIncidenciasUseCase]: el mapa quiere todo lo
/// que el servidor devuelve (corte en 1000 filas) de una sola vez, y los
/// campos son los del geojson, no los de la lista.
class ObtenerIncidenciasMapaUseCase {
  const ObtenerIncidenciasMapaUseCase(this._repo);

  final IncidenciaRepository _repo;

  Future<Result<List<IncidenciaMapa>>> call() => _repo.geojson();
}