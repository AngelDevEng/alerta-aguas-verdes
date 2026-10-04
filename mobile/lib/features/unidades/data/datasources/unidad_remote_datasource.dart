import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/parsing/lector_json.dart';
import '../../domain/entities/unidad.dart';
import '../../domain/repositories/unidad_repository.dart';
import '../models/unidad_dto.dart';

/// Fuente remota de unidades de serenazgo.
///
/// Vive en la feature `unidades` y no junto a `incidencias` aunque el dialogo de
/// despacho se abra desde el detalle de una incidencia: el recurso que se lee es
/// `unidades_serenazgo`, con sus propios endpoints y sus propios permisos.
///
/// El radio por defecto de [cercanas] lo decide `UnidadRepository` (dominio), no
/// esta clase.
///
/// Permisos (de `unidades.controller.ts`):
/// - `GET /unidades` y `GET /unidades/cercanas` exigen
///   `SERENO|OPERADOR|ADMIN|DIRECTIVO`.
/// - `POST /unidades` y `PATCH /unidades/:id/responsable` exigen `ADMIN` u
///   `OPERADOR`.
/// - `POST /unidades/:id/ubicaciones` exige `SERENO|OPERADOR|ADMIN`, y un
///   `SERENO` solo puede reportar la posicion de la unidad que tiene asignada.
abstract interface class UnidadRemoteDataSource {
  Future<Result<List<Unidad>>> listar();

  Future<Result<List<UnidadCercana>>> cercanas({
    required double longitud,
    required double latitud,
    double radioM,
  });
}

class UnidadRemoteDataSourceImpl implements UnidadRemoteDataSource {
  UnidadRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<Unidad>>> listar() => _api.get<List<Unidad>>(
        '/unidades',
        parse: (data) => aListaDeMapas(data)
            .map(UnidadDto.fromJson)
            .map((d) => d.toEntity())
            .toList(growable: false),
      );

  @override
  Future<Result<List<UnidadCercana>>> cercanas({
    required double longitud,
    required double latitud,
    double radioM = UnidadRepository.radioPorDefectoM,
  }) =>
      _api.get<List<UnidadCercana>>(
        '/unidades/cercanas',
        query: <String, dynamic>{
          'lon': longitud,
          'lat': latitud,
          'radio': radioM,
        },
        parse: (data) => aListaDeMapas(data)
            .map(UnidadCercanaDto.fromJson)
            .map((d) => d.toEntity())
            .toList(growable: false),
      );
}