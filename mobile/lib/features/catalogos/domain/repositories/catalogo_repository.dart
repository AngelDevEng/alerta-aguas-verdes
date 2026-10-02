import '../../../../core/error/result.dart';
import '../entities/catalogo.dart';

/// Contrato de catálogos, definido en `domain/`.
abstract interface class CatalogoRepository {
  Future<Result<List<ContactoEmergencia>>> emergencias();
  Future<Result<List<ContactoEmergencia>>> emergenciasWhatsapp();
  Future<Result<List<Asociacion>>> asociaciones();
}