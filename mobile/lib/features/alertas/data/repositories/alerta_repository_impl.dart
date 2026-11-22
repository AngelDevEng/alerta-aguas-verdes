import '../../../../core/error/result.dart';
import '../../domain/entities/alerta_sos.dart';
import '../../domain/repositories/alerta_repository.dart';
import '../datasources/alerta_remote_datasource.dart';

class AlertaRepositoryImpl implements AlertaRepository {
  AlertaRepositoryImpl(this._remote);

  final AlertaRemoteDataSource _remote;

  @override
  Future<Result<AlertaSos>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
    bool sinUbicacion = false,
    String? idempotencyKey,
  }) =>
      _remote.crearSos(
        latitud: latitud,
        longitud: longitud,
        precisionM: precisionM,
        sinUbicacion: sinUbicacion,
        idempotencyKey: idempotencyKey,
      );

  @override
  Future<Result<Map<String, dynamic>>> cambiarEstado(String id, String estado) =>
      _remote.cambiarEstado(id, estado);
}