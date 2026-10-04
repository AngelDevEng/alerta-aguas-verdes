import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/catalogo.dart';
import '../models/catalogos_dto.dart';

/// Fuente remota de catálogos.
///
/// Nota de seguridad: `emergencias` es `@Public()` en el backend, porque los
/// botones de SOS deben funcionar sin sesión. `asociaciones` sí exige token.
abstract interface class CatalogoRemoteDataSource {
  Future<Result<List<ContactoEmergencia>>> emergencias();
  Future<Result<List<ContactoEmergencia>>> emergenciasWhatsapp();
  Future<Result<List<Asociacion>>> asociaciones();
}

class CatalogoRemoteDataSourceImpl implements CatalogoRemoteDataSource {
  CatalogoRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  static List<Map<String, dynamic>> _lista(dynamic data) =>
      (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Future<Result<List<ContactoEmergencia>>> emergencias() =>
      _api.get<List<ContactoEmergencia>>(
        '/catalogos/emergencias',
        publico: true,
        parse: (data) => _lista(data)
            .map(ContactoEmergenciaDto.fromJson)
            .map((d) => d.toEntity())
            .toList(),
      );

  @override
  Future<Result<List<ContactoEmergencia>>> emergenciasWhatsapp() =>
      _api.get<List<ContactoEmergencia>>(
        '/catalogos/emergencias/whatsapp',
        publico: true,
        parse: (data) => _lista(data)
            .map(ContactoEmergenciaDto.fromJson)
            .map((d) => d.toEntity())
            .toList(),
      );

  @override
  Future<Result<List<Asociacion>>> asociaciones() =>
      _api.get<List<Asociacion>>(
        '/catalogos/asociaciones',
        parse: (data) => _lista(data)
            .map(AsociacionDto.fromJson)
            .map((d) => d.toEntity())
            .toList(),
      );
}

extension _ContactoX on ContactoEmergenciaDto {
  ContactoEmergencia toEntity() =>
      ContactoEmergencia(id: id, nombre: nombre, telefono: telefono, esWhatsapp: esWhatsapp);
}

extension _AsociacionX on AsociacionDto {
  Asociacion toEntity() => Asociacion(id: id, nombre: nombre);
}