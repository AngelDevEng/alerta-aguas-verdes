import '../../../../core/error/result.dart';
import '../entities/unidad.dart';

/// Contrato de lectura de unidades, definido en `domain/`.
///
/// Solo lectura a proposito. Escribir unidades (`POST /unidades`) es una tarea de
/// ADMIN y no tiene todavia pantalla; agregar el metodo aca sin implementarlo
/// obligaria a un `UnsupportedError` que el compilador noografia.
abstract interface class UnidadRepository {
  /// Radio por defecto de la busqueda de unidades cercanas, en metros.
  ///
  /// Vive en `domain/` y no en el datasource para que `usecases/` pueda
  /// ofrecerlo como default sin importar nada de `data/`: la flecha de
  /// dependencias siempre apunta hacia adentro. 3 km cubre un barrio; mas
  /// lejos la unidad no llega a tiempo y el operador tendria que hacer scroll
  /// infinito.
  static const radioPorDefectoM = 3000.0;

  Future<Result<List<Unidad>>> listar();

  /// Unidades dentro de un radio de [radioM] alrededor del punto, ordenadas por
  /// distancia de mas cerca a mas lejos (el backend ya las ordena).
  Future<Result<List<UnidadCercana>>> cercanas({
    required double longitud,
    required double latitud,
    double radioM,
  });

  /// Solo las unidades que se pueden despachar.
  ///
  /// Filtra aca y no en la UI para que la lista no dependa de que cada pantalla
  /// se acuerde del filtro: si el backend agrega un estado mas, hay que cambiar
  /// un solo lugar.
  ///
  /// Vive aca y no en el repositorio porque Dart no hereda implementaciones por
  /// defecto: si el metodo tuviera un cuerpo en la interfaz, cada
  /// implementacion tendria que repetirlo igual.
  Future<Result<List<Unidad>>> listarDespachables();
}