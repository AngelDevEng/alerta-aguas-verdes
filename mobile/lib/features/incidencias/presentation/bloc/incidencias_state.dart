import 'package:equatable/equatable.dart';

import '../../domain/entities/incidencia.dart';

/// Estados de la lista de incidencias.
sealed class IncidenciasState extends Equatable {
  const IncidenciasState({required this.filtros, this.tipos = const []});

  /// Filtros vigentes. Viajan en todos los estados para que la barra de
  /// filtros pueda mostrar la seleccion incluso mientras carga.
  final FiltrosIncidencia filtros;

  /// Opciones del filtro por tipo, ya con la etiqueta resuelta.
  ///
  /// Vive en la clase base y no solo en [IncidenciasListas] porque se deriva de
  /// lo ya cargado: si viviera en la hoja de "cargadas", abrir el filtro durante
  /// un refresh lo dejaria sin opciones y el filtro por tipo se desvaneceria en
  /// pantalla sin que el usuario hubiera tocado nada. Solo se vacia en la
  /// primera carga de todas, que es cuando todavia no hay nada de donde sacarlo.
  final List<TipoFiltro> tipos;

  /// Nombre legible del tipo [tipoId], o null si no esta entre los cargados.
  ///
  /// Un id a secas ("tipo 3") no le dice nada a quien lee la pantalla; el
  /// nombre viene del mismo dato que lleno el desplegable, asi que no hay forma
  /// de que sean incoherentes entre si.
  String? nombreDeTipo(int? tipoId) {
    if (tipoId == null) return null;
    for (final t in tipos) {
      if (t.id == tipoId) return t.nombre;
    }
    return null;
  }

  @override
  List<Object?> get props => [filtros, tipos];
}

/// Antes de la primera consulta.
class IncidenciasInicial extends IncidenciasState {
  const IncidenciasInicial() : super(filtros: const FiltrosIncidencia());
}

/// Consultando.
///
/// [previo] conserva la pagina que ya estaba en pantalla, para poder pintar la
/// lista mientras recarga en vez de taparla con un spinner. Es null solo en la
/// primera carga de todas.
class IncidenciasCargando extends IncidenciasState {
  const IncidenciasCargando({required super.filtros, super.tipos, this.previo});

  final PaginaIncidencias? previo;

  @override
  List<Object?> get props => [...super.props, previo];
}

/// Con datos.
class IncidenciasListas extends IncidenciasState {
  const IncidenciasListas({
    required super.filtros,
    required super.tipos,
    required this.pagina,
  });

  final PaginaIncidencias pagina;

  @override
  List<Object?> get props => [...super.props, pagina];
}

/// Error de la ultima consulta.
///
/// Conserva la pagina previa en [previo] para que la pantalla pueda mostrar la
/// lista con un aviso en vez de quedar en blanco.
class IncidenciasError extends IncidenciasState {
  const IncidenciasError({
    required super.filtros,
    super.tipos,
    required this.mensaje,
    this.previo,
  });

  final String mensaje;
  final PaginaIncidencias? previo;

  @override
  List<Object?> get props => [...super.props, mensaje, previo];
}

/// Opcion del filtro por tipo, ya con la etiqueta resuelta.
class TipoFiltro extends Equatable {
  const TipoFiltro({required this.id, required this.nombre});

  final int id;
  final String nombre;

  @override
  List<Object?> get props => [id, nombre];
}