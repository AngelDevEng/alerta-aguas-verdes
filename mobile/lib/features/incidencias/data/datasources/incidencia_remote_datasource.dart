import 'package:dio/dio.dart';

import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/detalle_incidencia.dart';
import '../../domain/entities/evidencia.dart';
import '../../domain/entities/incidencia.dart';
import '../../domain/entities/tipo_incidencia.dart';
import '../models/detalle_incidencia_dto.dart';
import '../models/incidencias_dto.dart';

/// Fuente remota de incidencias.
///
/// Nota de permisos, por endpoint y no por recurso:
/// - `POST /incidencias` acepta `CIUDADANO|SERENO|OPERADOR|ADMIN`.
/// - `GET /incidencias`, `GET /incidencias/:id` exigen
///   `SERENO|OPERADOR|ADMIN|DIRECTIVO`. Un ciudadano NO puede ver la lista ni el
///   detalle, pero si puede reportar.
/// - `POST /incidencias/:id/evidencias` exige `SERENO|OPERADOR|ADMIN`, asi que
///   un ciudadano que adjunta fotos recibe 403 y hay que tratarlo aparte del
///   alta: el reporte ya quedo guardado y no se debe perder por una foto.
/// - `PATCH /incidencias/:id/estado` exige `SERENO|OPERADOR|ADMIN`.
/// - `PATCH /incidencias/:id/asignar` exige `OPERADOR|ADMIN`: despachar es
///   decision del operador, un sereno avanza el estado pero no elige unidad.
///
/// Que los permisos difieran por endpoint y no por recurso es lo que obliga a
/// revisar esta lista cada vez que se toca el backend. Un unico
/// `puedeDespachar` en la UI habria que rivalizar con esta tabla.
abstract interface class IncidenciaRemoteDataSource {
  Future<Result<PaginaIncidencias>> listar(FiltrosIncidencia filtros);

  Future<Result<DetalleIncidencia>> obtenerDetalle(String id);

  /// Crea la incidencia y devuelve el id generado por el servidor.
  Future<Result<String>> crear(NuevaIncidencia datos);

  /// Sube una evidencia. [onProgress] recibe enviados/totales, 0..1.
  Future<Result<Evidencia>> subirEvidencia(
    String incidenciaId,
    EvidenciaAdjunta evidencia, {
    ProgressCallback? onProgress,
  });

  /// Avanza el estado y devuelve el detalle actualizado.
  Future<Result<DetalleIncidencia>> cambiarEstado(String id, EstadoIncidencia estado);

  /// Despacha una unidad y devuelve el detalle actualizado.
  Future<Result<DetalleIncidencia>> asignarUnidad(String id, String unidadId);
}

class IncidenciaRemoteDataSourceImpl implements IncidenciaRemoteDataSource {
  IncidenciaRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  static Map<String, dynamic> _mapa(dynamic data) =>
      Map<String, dynamic>.from(data as Map);

  @override
  Future<Result<PaginaIncidencias>> listar(FiltrosIncidencia filtros) =>
      _api.get<PaginaIncidencias>(
        '/incidencias',
        query: filtros.toQuery(),
        // El parseo devuelve entidades, no DTOs: el repositorio no necesita
        // conocer la forma del JSON.
        parse: (data) =>
            PaginaIncidenciasDto.fromJson(_mapa(data)).toEntity(),
      );

  @override
  Future<Result<DetalleIncidencia>> obtenerDetalle(String id) =>
      _api.get<DetalleIncidencia>(
        '/incidencias/$id',
        parse: (data) => DetalleIncidenciaDto.fromJson(_mapa(data)).toEntity(),
      );

  @override
  Future<Result<String>> crear(NuevaIncidencia datos) => _api.post<String>(
        '/incidencias',
        body: NuevaIncidenciaRequest(datos).toJson(),
        parse: (data) => IncidenciaCreadaDto.fromJson(_mapa(data)).id,
      );

  @override
  Future<Result<Evidencia>> subirEvidencia(
    String incidenciaId,
    EvidenciaAdjunta evidencia, {
    ProgressCallback? onProgress,
  }) async {
    // El archivo se manda como `MultipartFile.fromFile`, que lo sube en
    // streaming: una foto de 12 MB no se carga entera en memoria del lado
    // Dart, y el `sendTimeout` de 30 s alcanza sinretenerse en el socket.
    final form = FormData.fromMap({
      'archivo': await MultipartFile.fromFile(
        evidencia.ruta,
        filename: evidencia.nombre,
      ),
      if (evidencia.latitud != null) 'latitud': evidencia.latitud,
      if (evidencia.longitud != null) 'longitud': evidencia.longitud,
    });

    return _api.upload<Evidencia>(
      '/incidencias/$incidenciaId/evidencias',
      formData: form,
      onProgress: onProgress,
      parse: (data) => EvidenciaDto.fromJson(_mapa(data)).toEntity(),
    );
  }

  @override
  Future<Result<DetalleIncidencia>> cambiarEstado(
    String id,
    EstadoIncidencia estado,
  ) =>
      _api.patch<DetalleIncidencia>(
        '/incidencias/$id/estado',
        body: CambiarEstadoRequest(estado).toJson(),
        parse: (data) => DetalleIncidenciaDto.fromJson(_mapa(data)).toEntity(),
      );

  @override
  Future<Result<DetalleIncidencia>> asignarUnidad(String id, String unidadId) =>
      _api.patch<DetalleIncidencia>(
        '/incidencias/$id/asignar',
        body: AsignarUnidadRequest(unidadId).toJson(),
        parse: (data) => DetalleIncidenciaDto.fromJson(_mapa(data)).toEntity(),
      );
}