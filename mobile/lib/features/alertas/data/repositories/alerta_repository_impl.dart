import '../../../../core/error/result.dart';
import '../../domain/repositories/alerta_repository.dart';
import '../datasources/alerta_remote_datasource.dart';

class AlertaRepositoryImpl implements AlertaRepository {
  AlertaRepositoryImpl(this._remote);

  final AlertaRemoteDataSource _remote;

  @override
  Future<Result<String>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
  }) =>
      _remote.crearSos(
        latitud: latitud,
        longitud: longitud,
        precisionM: precisionM,
      );
}
