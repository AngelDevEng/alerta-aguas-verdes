import '../../../../core/error/result.dart';
import '../../domain/entities/detalle_incidencia.dart';
import '../../domain/entities/evidencia.dart';
import '../../domain/entities/incidencia.dart';
import '../../domain/entities/tipo_incidencia.dart';
import '../../domain/repositories/incidencia_repository.dart';
import '../datasources/incidencia_remote_datasource.dart';

class IncidenciaRepositoryImpl implements IncidenciaRepository {
  IncidenciaRepositoryImpl(this._remote);

  final IncidenciaRemoteDataSource _remote;

  @override
  Future<Result<PaginaIncidencias>> listar(FiltrosIncidencia filtros) =>
      _remote.listar(filtros);

  @override
  Future<Result<DetalleIncidencia>> obtenerDetalle(String id) =>
      _remote.obtenerDetalle(id);

  @override
  Future<Result<String>> crear(NuevaIncidencia datos) => _remote.crear(datos);

  @override
  Future<Result<Evidencia>> subirEvidencia(
    String incidenciaId,
    EvidenciaAdjunta evidencia,
  ) =>
      _remote.subirEvidencia(incidenciaId, evidencia);

  @override
  Future<Result<DetalleIncidencia>> cambiarEstado(
    String id,
    EstadoIncidencia estado,
  ) =>
      _remote.cambiarEstado(id, estado);

  @override
  Future<Result<DetalleIncidencia>> asignarUnidad(String id, String unidadId) =>
      _remote.asignarUnidad(id, unidadId);

  @override
  List<TipoIncidenciaDisponible> tiposDisponibles(
    List<Incidencia> cargadas, {
    List<TipoIncidenciaDisponible> previos = const [],
  }) {
    // Set por id: dos incidencias del mismo tipo traen repetido el nombre.
    final vistos = <int, String>{for (final t in previos) t.id: t.nombre};
    for (final i in cargadas) {
      if (i.tipoId > 0 && i.tipo.isNotEmpty) {
        // `putIfAbsent`: el nombre ya conocido gana sobre el de esta pagina.
        vistos.putIfAbsent(i.tipoId, () => i.tipo);
      }
    }
    return vistos.entries
        .map((e) => TipoIncidenciaDisponible(id: e.key, nombre: e.value))
        .toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
  }
}