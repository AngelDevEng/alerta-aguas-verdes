import '../../../../core/error/result.dart';
import '../../domain/entities/unidad.dart';
import '../../domain/repositories/unidad_repository.dart';

/// Unidades que se pueden asignar a una incidencia.
///
/// El filtro por `DISPONIBLE` vive en el repositorio, asi que esta pantalla no
/// puede ofrecer una unidad ocupada por accidente.
class ListarUnidadesDespachablesUseCase {
  const ListarUnidadesDespachablesUseCase(this._repo);

  final UnidadRepository _repo;

  Future<Result<List<Unidad>>> call() => _repo.listarDespachables();
}

/// Unidades cercanas a un punto, para sugerir la mas logica.
///
/// Complementa a [ListarUnidadesDespachablesUseCase]: la primera responde "a
/// quien puedo despachar" y esta "a quien le queda mas cerca".
class ListarUnidadesCercanasUseCase {
  const ListarUnidadesCercanasUseCase(this._repo);

  final UnidadRepository _repo;

  Future<Result<List<UnidadCercana>>> call({
    required double longitud,
    required double latitud,
    double radioM = UnidadRepository.radioPorDefectoM,
  }) =>
      _repo.cercanas(longitud: longitud, latitud: latitud, radioM: radioM);
}