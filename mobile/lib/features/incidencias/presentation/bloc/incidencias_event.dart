import 'package:equatable/equatable.dart';

import '../../domain/entities/incidencia.dart';

/// Eventos de la lista de incidencias.
sealed class IncidenciasEvent extends Equatable {
  const IncidenciasEvent();

  @override
  List<Object?> get props => const [];
}

/// Primera carga o recarga conservando filtros.
///
/// Se dispara al abrir la pantalla para que el usuario no espere un boton.
class CargarIncidencias extends IncidenciasEvent {
  const CargarIncidencias({this.filtros});

  /// Si es null se reutilizan los filtros ya aplicados, para que el pull to
  /// refresh no vuelva a la pagina 1.
  final FiltrosIncidencia? filtros;

  @override
  List<Object?> get props => [filtros];
}

/// Cambia un filtro y vuelve a la pagina 1.
///
/// Volver a 1 es lo correcto: al filtrar, la pagina 4 puede quedar vacia y
/// parece un error.
class AplicarFiltros extends IncidenciasEvent {
  const AplicarFiltros({
    this.estado,
    this.tipoId,
    this.desde,
    this.hasta,
    this.limpiarEstado = false,
    this.limpiarTipo = false,
    this.limpiarDesde = false,
    this.limpiarHasta = false,
  });

  final EstadoIncidencia? estado;
  final int? tipoId;
  final DateTime? desde;
  final DateTime? hasta;
  final bool limpiarEstado;
  final bool limpiarTipo;
  final bool limpiarDesde;
  final bool limpiarHasta;

  @override
  List<Object?> get props =>
      [estado, tipoId, desde, hasta, limpiarEstado, limpiarTipo, limpiarDesde, limpiarHasta];
}

/// Quita todos los filtros y recarga.
class LimpiarFiltros extends IncidenciasEvent {
  const LimpiarFiltros();
}

/// Avanza o retrocede de pagina, conservando los filtros.
class CambiarPagina extends IncidenciasEvent {
  const CambiarPagina(this.pagina);

  final int pagina;

  @override
  List<Object?> get props => [pagina];
}