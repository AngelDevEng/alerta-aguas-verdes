import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/detalle_incidencia.dart';

/// Estados de la pantalla de detalle.
///
/// A diferencia de la lista, aqui el estado es plano y no hay una clase base con
/// los filtros: son cuatro casos y tres de ellos llevan el mismo payload. El
/// modelo de la lista se complico por el paginado, que el detalle no tiene.
sealed class IncidenciaDetalleState extends Equatable {
  const IncidenciaDetalleState();

  @override
  List<Object?> get props => const [];
}

/// Antes de la primera carga.
class DetalleInicial extends IncidenciaDetalleState {
  const DetalleInicial();
}

/// Primera carga en curso, sin nada que mostrar todavia.
class DetalleCargando extends IncidenciaDetalleState {
  const DetalleCargando();
}

/// Detalle disponible.
///
/// [accionEnCurso] distingue "hice pull-to-refresh" de "estoy despachando": en
/// el primer caso la pantalla se puede recargar entera, en el segundo no,
/// porque tapar la pantalla mientras se guarda el despacho hace que el operador
/// dude si funciono y pulse dos veces.
class DetalleCargado extends IncidenciaDetalleState {
  const DetalleCargado(this.detalle, {this.accionEnCurso = false});

  final DetalleIncidencia detalle;

  /// Hay un `PATCH` en vuelo.
  final bool accionEnCurso;

  DetalleCargado copyWith({DetalleIncidencia? detalle, bool? accionEnCurso}) =>
      DetalleCargado(
        detalle ?? this.detalle,
        accionEnCurso: accionEnCurso ?? this.accionEnCurso,
      );

  @override
  List<Object?> get props => [detalle, accionEnCurso];
}

/// No se pudo cargar y no hay nada previo que conservar.
///
/// En este caso se pierde el detalle, a diferencia de la lista: sin cache local
/// no hay de donde recuperarlo.
class DetalleError extends IncidenciaDetalleState {
  const DetalleError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Vista unificada de los estados que tienen detalle en pantalla.
///
/// La pantalla recibia el detalle por dos caminos (estado cargado o el "anterior"
/// de un fallo de accion) y eso obligaba a repetir el mismo `switch` en el
/// `AppBar`, en el cuerpo y en la barra de despacho. Con un solo accesor los tres
/// leen lo mismo y no pueden desincronizarse: si se agrega un estado con
/// detalle, hay que actualizar un metodo y no tres.
extension DetalleVisible on IncidenciaDetalleState {
  /// Detalle a mostrar, o null si todavia no hay nada.
  DetalleIncidencia? get detalle => switch (this) {
        DetalleCargado(:final detalle) => detalle,
        DetalleAccionFallida(:final anterior) => anterior.detalle,
        _ => null,
      };

  /// Si hay un `PATCH` en vuelo, sea sobre el estado cargado o sobre el anterior.
  bool get accionEnCurso => switch (this) {
        DetalleCargado(:final accionEnCurso) => accionEnCurso,
        DetalleAccionFallida(:final anterior) => anterior.accionEnCurso,
        _ => false,
      };
}

/// Una accion fallida sobre un detalle que sigue visible.
///
/// Se distingue de [DetalleError] justamente para eso: la incidencia sigue en
/// pantalla y el error va en un `SnackBar`. Perder el detalle porque una unidad
/// ya no estaba disponible seria una perdida de informacion gratis.
///
/// [anterior] guarda el ultimo estado sano. Sin el, cerrar el `SnackBar` obliga a
/// un refetch solo para volver a tener algo que pintar, y recargar la pantalla
/// para limpiar un mensaje es una forma cara de hacer ruido.
class DetalleAccionFallida extends IncidenciaDetalleState {
  const DetalleAccionFallida(
    this.failure, {
    required this.anterior,
    this.mostrarBorrador = false,
  });

  final Failure failure;

  /// Estado cargado previo a la accion fallida.
  final DetalleCargado anterior;

  /// Si el fallo fue al asignar unidad, el dialogo sigue abierto para que el
  /// operador pueda elegir otra sin reabrirlo.
  final bool mostrarBorrador;

  @override
  List<Object?> get props => [failure, anterior, mostrarBorrador];
}