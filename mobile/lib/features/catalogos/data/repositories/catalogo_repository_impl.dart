import '../../../../core/error/result.dart';
import '../../domain/entities/catalogo.dart';
import '../../domain/repositories/catalogo_repository.dart';
import '../datasources/catalogo_remote_datasource.dart';

/// Implementación del contrato de dominio.
///
/// Hoy es un proxy transparente. El día que haya cache offline del catálogo
/// (para que el SOS funcione sin señal) se resuelve aquí la regla de caché, sin
/// tocar BLoC ni widgets.
class CatalogoRepositoryImpl implements CatalogoRepository {
  CatalogoRepositoryImpl(this._remote);

  final CatalogoRemoteDataSource _remote;

  @override
  Future<Result<List<ContactoEmergencia>>> emergencias() => _remote.emergencias();

  @override
  Future<Result<List<ContactoEmergencia>>> emergenciasWhatsapp() =>
      _remote.emergenciasWhatsapp();

  @override
  Future<Result<List<Asociacion>>> asociaciones() => _remote.asociaciones();
}