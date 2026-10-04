import '../../../../core/error/result.dart';
import '../../domain/entities/unidad.dart';
import '../../domain/repositories/unidad_repository.dart';
import '../datasources/unidad_remote_datasource.dart';

class UnidadRepositoryImpl implements UnidadRepository {
  UnidadRepositoryImpl(this._remote);

  final UnidadRemoteDataSource _remote;

  @override
  Future<Result<List<Unidad>>> listar() => _remote.listar();

  @override
  Future<Result<List<UnidadCercana>>> cercanas({
    required double longitud,
    required double latitud,
    double radioM = UnidadRepository.radioPorDefectoM,
  }) =>
      _remote.cercanas(longitud: longitud, latitud: latitud, radioM: radioM);

  @override
  Future<Result<List<Unidad>>> listarDespachables() async {
    final resultado = await listar();
    return switch (resultado) {
      Ok<List<Unidad>>(:final value) => Ok<List<Unidad>>(
          value.where((u) => u.estado.asignable).toList(growable: false),
        ),
      Err<List<Unidad>>(:final failure) => Err<List<Unidad>>(failure),
    };
  }
}