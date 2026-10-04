import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/detalle_incidencia.dart';
import '../bloc/incidencia_detalle_bloc.dart';
import '../bloc/incidencia_detalle_event.dart';
import '../bloc/incidencia_detalle_state.dart';
import '../widgets/detalle_widgets.dart';
import '../widgets/selector_unidad_sheet.dart';

/// Detalle de una incidencia: datos, evidencias, historial y despacho.
///
/// La barra de acciones no se decide en el widget sino en [Usuario]: los mismos
/// roles que valida `@Roles` en el backend. Mostrar un boton que el servidor
/// va a rechazar con 403 es peor que no mostrarlo.
class IncidenciaDetallePage extends StatelessWidget {
  const IncidenciaDetallePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      // Dos cosas distinta pasan por el listener: el fallo de una accion (que
      // avisa) y el exito (que devuelve `true` a la lista). El filtro se queda
      // con `accionEnCurso` porque distingue las dos: sin el, una recarga manual
      // durante un despacho se contaria como cambio de estado.
      listenWhen: (a, b) =>
          b is DetalleAccionFallida ||
          (a.accionEnCurso && !b.accionEnCurso && b.detalle != null),
      listener: _alCambiarEstado,
      builder: (context, state) {
        final detalle = state.detalle;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              (detalle?.incidencia.codigo.isEmpty ?? true)
                  ? 'Detalle'
                  : detalle!.incidencia.codigo,
            ),
            actions: [
              // Refrescar solo tiene sentido con algo que refrescar. Con el
              // spinner de una accion en vuelo se omite para no disparar una
              // consulta que el backend va a responder con el estado viejo.
              if (detalle != null && !state.accionEnCurso)
                IconButton(
                  tooltip: 'Recargar',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _recargar(context),
                ),
            ],
          ),
          body: switch (state) {
            DetalleInicial() || DetalleCargando() =>
              const Center(child: CircularProgressIndicator()),
            DetalleError(:final failure) => DetalleErrorTotal(
                failure: failure,
                onReintentar: () => _recargar(context),
              ),
            // Un fallo de accion no cambia el cuerpo: el detalle sigue siendo
            // valido y el aviso ya fue por `SnackBar`.
            _ => _Cuerpo(detalle: detalle!),
          },
        );
      },
    );
  }

  static void _recargar(BuildContext context) => context
      .read<IncidenciaDetalleBloc>()
      .add(const DetalleSolicitado());

  /// Avisos flotantes y reapertura del dialogo de unidades.
  void _alCambiarEstado(BuildContext context, IncidenciaDetalleState state) {
    // Exito de una accion: la lista recarga para no mostrar el estado viejo.
    if (state is! DetalleAccionFallida) {
      context.pop(true);
      return;
    }

    if (state case DetalleAccionFallida(
          :final failure,
          :final mostrarBorrador,
          :final anterior
        )) {
      final messenger = ScaffoldMessenger.of(context);

      if (mostrarBorrador) {
        // Reabre la hoja para que el operador elija otra sin repetir el camino.
        // Va antes del `SnackBar` para que el dialogo quede encima.
        SelectorUnidadSheet.mostrar(
          context,
          unidadActualId: anterior.detalle.incidencia.unidadAsignadaId,
        ).then((unidadId) {
          if (unidadId == null || !context.mounted) return;
          context
              .read<IncidenciaDetalleBloc>()
              .add(DetalleUnidadAsignada(unidadId));
        });
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message),
          // Un 403 no se arregla reintentando: el boton seria ruido.
          action: failure is ForbiddenFailure || failure is AuthFailure
              ? null
              : SnackBarAction(
                  label: 'Reintentar',
                  onPressed: () =>
                      context.read<IncidenciaDetalleBloc>().add(const DetalleAvisoDescartado()),
                ),
        ),
      );
    }
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({required this.detalle});

  final DetalleIncidencia detalle;

  @override
  Widget build(BuildContext context) {
    final inc = detalle.incidencia;

    return RefreshIndicator(
      // El pull-to-refresh recarga por el mismo camino que el boton de la barra:
      // un camino solo, para que un fallo se comporte igual en los dos.
      onRefresh: () async =>
          context.read<IncidenciaDetalleBloc>().add(const DetalleSolicitado()),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          DetalleCabecera(incidencia: inc),
          const SizedBox(height: 18),
          DetalleDatos(incidencia: inc),
          const SizedBox(height: 20),
          DetalleEvidencias(evidencias: detalle.evidencias),
          const SizedBox(height: 20),
          DetalleHistorial(historial: detalle.historial),
          if (inc.unidadAsignadaId != null) ...[
            const SizedBox(height: 20),
            _UnidadAsignada(id: inc.unidadAsignadaId!),
          ],
          const SizedBox(height: 24),
          const _BarraDespacho(),
        ],
      ),
    );
  }
}

/// Bloque de despacho, al final de la lista.
///
/// Va abajo a proposito: el operador lee primero que paso y despues decide.
/// Ponerlo arriba taparia la descripcion con un boton que todavia no sabe si
/// tiene sentido.
class _BarraDespacho extends StatelessWidget {
  const _BarraDespacho();

  @override
  Widget build(BuildContext context) {
    final estado = context.select<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      (b) => b.state,
    );

    return switch (estado) {
      DetalleCargado(:final detalle) => _contexto(context, detalle, estado),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _contexto(
    BuildContext context,
    DetalleIncidencia detalle,
    IncidenciaDetalleState state,
  ) {
    final usuario = switch (context.watch<AuthBloc>().state) {
      AuthAutenticado(:final usuario) => usuario,
      _ => null,
    };

    // Sin sesion no se ofrece nada: el backend responderia 401 igual. Passar los
    // flags por los constructores de cada widget seria ruido en el arbol.
    if (usuario == null) return const SizedBox.shrink();

    return DetalleAcciones(
      estado: detalle.incidencia.estado,
      puedeAsignar: usuario.puedeDespachar,
      puedeCambiarEstado: usuario.puedeCambiarEstado,
      enCurso: state.accionEnCurso,
      onEstado: (e) =>
          context.read<IncidenciaDetalleBloc>().add(DetalleEstadoCambiado(e)),
      onAsignar: () => _elegirUnidad(context, detalle),
    );
  }

  Future<void> _elegirUnidad(
    BuildContext context,
    DetalleIncidencia detalle,
  ) async {
    final bloc = context.read<IncidenciaDetalleBloc>();
    final unidadId = await SelectorUnidadSheet.mostrar(
      context,
      unidadActualId: detalle.incidencia.unidadAsignadaId,
    );
    // `unawaited` no hace falta: la pantalla se cierra solo cuando el `PATCH`
    // termina, y no hay nada que esperar en este `async`.
    if (unidadId == null) return;
    bloc.add(DetalleUnidadAsignada(unidadId));
  }
}

/// Datos de la unidad asignada.
///
/// `SELECT_BASE` de incidencias solo trae `unidadAsignadaId`, no el nombre: el
/// nombre de la unidad vive en `GET /unidades/:id`, que no se pide. Mostrar el
/// id crudo seria ilegible, asi que se muestra el identificador corto que el
/// backend no envia y se evita el viaje extra. Cuando se quiera el nombre real,
/// el endpoint es `GET /unidades/:id`.
class _UnidadAsignada extends StatelessWidget {
  const _UnidadAsignada({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corto = id.length > 8 ? '${id.substring(0, 8)}…' : id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.legacy.verde.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_car_outlined, color: context.legacy.verde),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unidad despachada', style: theme.textTheme.labelMedium),
                Text(corto, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
