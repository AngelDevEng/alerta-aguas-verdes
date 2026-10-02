import '../../../../core/error/result.dart';
import '../entities/catalogo.dart';
import '../repositories/catalogo_repository.dart';

/// Carga los contactos de la central telefónica.
///
/// Es un caso de uso trivial a proposito: deja fijada la frontera para cuando
/// el catálogo pase a filtrarse por rol o a venir cacheado.
class ObtenerEmergenciasUseCase {
  const ObtenerEmergenciasUseCase(this._repo);

  final CatalogoRepository _repo;

  Future<Result<List<ContactoEmergencia>>> call() => _repo.emergencias();
}

/// Variante que devuelve solo los contactos con WhatsApp.
class ObtenerEmergenciasWhatsappUseCase {
  const ObtenerEmergenciasWhatsappUseCase(this._repo);

  final CatalogoRepository _repo;

  Future<Result<List<ContactoEmergencia>>> call() => _repo.emergenciasWhatsapp();
}

/// Catálogo de asociaciones de vivienda. Exige rol de operador.
class ObtenerAsociacionesUseCase {
  const ObtenerAsociacionesUseCase(this._repo);

  final CatalogoRepository _repo;

  Future<Result<List<Asociacion>>> call() => _repo.asociaciones();
}