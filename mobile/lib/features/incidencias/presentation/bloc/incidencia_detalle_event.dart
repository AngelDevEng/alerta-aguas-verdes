import 'package:equatable/equatable.dart';

import '../../domain/entities/incidencia.dart';

/// Eventos de la pantalla de detalle de una incidencia.
///
/// La carga y las acciones van separadas a proposito: recargar es idempotente y
/// destructivo de datos, cambiar el estado y despachar no. Mezclarlos en un
/// `Actualizar` habia hecho que un pull-to-refresh pudiera reenviar un despacho.
sealed class IncidenciaDetalleEvent extends Equatable {
  const IncidenciaDetalleEvent();

  @override
  List<Object?> get props => const [];
}

/// Carga (o recarga) el detalle.
class DetalleSolicitado extends IncidenciaDetalleEvent {
  const DetalleSolicitado();
}

/// Avanza el estado de la incidencia.
class DetalleEstadoCambiado extends IncidenciaDetalleEvent {
  const DetalleEstadoCambiado(this.estado);

  final EstadoIncidencia estado;

  @override
  List<Object?> get props => [estado];
}

/// Despacha una unidad.
class DetalleUnidadAsignada extends IncidenciaDetalleEvent {
  const DetalleUnidadAsignada(this.unidadId);

  final String unidadId;

  @override
  List<Object?> get props => [unidadId];
}

/// Limpia el mensaje de error de una accion fallida.
///
/// Se dispara desde el `SnackBar` para que el mensaje no quede pegado si el
/// usuario navega a otra pantalla y vuelve.
class DetalleAvisoDescartado extends IncidenciaDetalleEvent {
  const DetalleAvisoDescartado();
}