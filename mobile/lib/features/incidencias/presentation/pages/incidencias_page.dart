import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/incidencia.dart';
import '../bloc/incidencias_bloc.dart';
import '../bloc/incidencias_event.dart';
import '../bloc/incidencias_state.dart';
import '../widgets/filtros_sheet.dart';
import '../widgets/incidencia_tile.dart';

/// Lista de incidencias con filtros por estado, tipo y fecha.
///
/// Reemplaza el placeholder que solo mostraba un texto. El BLoC se crea en la
/// ruta (`app_router.dart`) y dispara la carga inicial, asi que esta pantalla
/// solo despacha eventos y dibuja estados.
class IncidenciasPage extends StatelessWidget {
  const IncidenciasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidencias'),
        actions: const [_BotonFiltros()],
      ),
      body: BlocBuilder<IncidenciasBloc, IncidenciasState>(
        builder: (context, state) {
          return switch (state) {
            // Primera carga: no hay nada que pintar todavia.
            IncidenciasInicial() => const _Cargando(),
            IncidenciasCargando(:final previo) when previo == null => const _Cargando(),
            // Recarga sobre datos existentes: se mantiene la lista visible.
            IncidenciasCargando() => _Lista(state: state, refrescando: true),
            IncidenciasListas() => _Lista(state: state, refrescando: false),
            // Fallo sin historial: error a pantalla completa con reintento.
            IncidenciasError(:final previo) when previo == null => _ErrorVacio(
                mensaje: state.mensaje,
                onReintentar: () =>
                    context.read<IncidenciasBloc>().add(const CargarIncidencias()),
              ),
            // Fallo con historial: lista mas aviso, sin perder lo cargado.
            IncidenciasError() => _Lista(state: state, refrescando: false),
          };
        },
      ),
    );
  }
}

class _BotonFiltros extends StatelessWidget {
  const _BotonFiltros();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IncidenciasBloc, IncidenciasState>(
      buildWhen: (a, b) => a.filtros != b.filtros,
      builder: (context, state) {
        final activos = _contarFiltros(state.filtros);
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: 'Filtros',
              icon: const Icon(Icons.filter_list),
              onPressed: () => _abrirFiltros(context, state),
            ),
            if (activos > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.legacy.rojo,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$activos',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Abre el detalle y recarga si el caso cambio.
///
/// Devuelve `true` desde el detalle cuando hubo un despacho, para que la lista
/// no muestre el estado anterior. Un reload completo y no un parche local: el
/// backend puede haber derivado otras cosas del caso (la unidad asignada pasa a
/// `OCUPADA`, la incidencia a `DESPACHADA`) que la fila de la lista no puede
/// saber sola.
Future<void> _abrirDetalle(BuildContext context, String id) async {
  final cambio = await context.push<bool>('/incidencias/$id');
  if (cambio == true && context.mounted) {
    context.read<IncidenciasBloc>().add(const CargarIncidencias());
  }
}

Future<void> _abrirFiltros(BuildContext context, IncidenciasState state) async {
  final bloc = context.read<IncidenciasBloc>();

  final resultado = await showModalBottomSheet<FiltrosIncidencia>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    // `tipos` viene del estado base, que los conserva tambien mientras carga: si
    // se leyera solo de `IncidenciasListas`, abrir el filtro durante un refresh
    // lo abriria sin opciones.
    builder: (_) => FiltrosSheet(filtros: state.filtros, tipos: state.tipos),
  );

  if (resultado != null) {
    bloc.add(AplicarFiltros(
      estado: resultado.estado,
      tipoId: resultado.tipoId,
      desde: resultado.desde,
      hasta: resultado.hasta,
      limpiarEstado: resultado.estado == null,
      limpiarTipo: resultado.tipoId == null,
      limpiarDesde: resultado.desde == null,
      limpiarHasta: resultado.hasta == null,
    ));
  }
}

int _contarFiltros(FiltrosIncidencia f) => [
      f.estado != null,
      f.tipoId != null,
      f.desde != null,
      f.hasta != null,
    ].where((e) => e).length;

class _Lista extends StatelessWidget {
  const _Lista({required this.state, required this.refrescando});

  final IncidenciasState state;
  final bool refrescando;

  @override
  Widget build(BuildContext context) {
    // `_Lista` solo se construye cuando hay una pagina previa que mostrar; los
// estados sin datos van a su propia vista.
final pagina = switch (state) {
      IncidenciasListas(:final pagina) => pagina,
      IncidenciasError(:final previo) => previo,
      IncidenciasCargando(:final previo) => previo,
      _ => const PaginaIncidencias.vacia(),
    } ??
        const PaginaIncidencias.vacia();

    final aviso = state is IncidenciasError ? (state as IncidenciasError).mensaje : null;

    return Column(
      children: [
        if (aviso != null) _AvisoError(mensaje: aviso),
        _Resumen(state: state, total: pagina.total),
        Expanded(
          child: RefreshIndicator(
            // En refresh se conservan filtros y pagina: recargar no es filtrar.
            onRefresh: () async {
              final bloc = context.read<IncidenciasBloc>();
              bloc.add(const CargarIncidencias());
              await bloc.stream.firstWhere((s) => s is! IncidenciasCargando);
            },
            child: pagina.items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      _Vacio(
                        icono: Icons.search_off,
                        titulo: 'Sin resultados',
                        mensaje: 'No hay incidencias que cumplan el filtro.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: pagina.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final incidencia = pagina.items[i];
                      return IncidenciaTile(
                        incidencia: incidencia,
                        // Sin este `onTap` la lista era un callejon sin salida:
                        // el datasource traia `GET /incidencias/:id` y ninguna
                        // pantalla lo llamaba, asi que no habia forma de ver las
                        // evidencias ni despachar.
                        //
                        // Se espera el resultado porque el detalle devuelve
                        // `true` si toco el estado o la unidad: la fila quedaria
                        // con el dato viejo y el operador veria "Registrada"
                        // junto a un caso recien despachado.
                        onTap: () => _abrirDetalle(context, incidencia.id),
                      );
                    },
                  ),
          ),
        ),
        if (pagina.totalPaginas > 1)
          _Paginacion(pagina: pagina, refrescando: refrescando),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.state, required this.total});

  final IncidenciasState state;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtros = state.filtros;

    // El tipo se muestra por nombre, no por id. Antes decia "tipo 3", que no le
    // dice nada a quien lo lee; el nombre sale de los mismos datos que armaron
    // el desplegable, asi que no puede quedar desalineado con el.
    final nombreTipo = state.nombreDeTipo(filtros.tipoId);

    final chips = <Widget>[
      if (filtros.estado != null)
        Chip(label: Text(filtros.estado!.etiqueta)),
      if (filtros.tipoId != null)
        Chip(label: Text(nombreTipo ?? 'Tipo ${filtros.tipoId}')),
      if (filtros.desde != null) Chip(label: Text('desde')),
      if (filtros.hasta != null) Chip(label: Text('hasta')),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total ${total == 1 ? "incidencia" : "incidencias"}',
            style: theme.textTheme.labelLarge,
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: chips),
          ],
        ],
      ),
    );
  }
}

class _Paginacion extends StatelessWidget {
  const _Paginacion({required this.pagina, required this.refrescando});

  final PaginaIncidencias pagina;
  final bool refrescando;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<IncidenciasBloc>();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(
          children: [
            Text(
              'Pagina ${pagina.page} de ${pagina.totalPaginas}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const Spacer(),
            IconButton.filledTonal(
              tooltip: 'Anterior',
              onPressed: (!pagina.hayAnterior || refrescando)
                  ? null
                  : () => bloc.add(CambiarPagina(pagina.page - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Siguiente',
              onPressed: (!pagina.haySiguiente || refrescando)
                  ? null
                  : () => bloc.add(CambiarPagina(pagina.page + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  const _AvisoError({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final legacy = context.legacy;
    return Material(
      color: legacy.rojo.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 18, color: legacy.rojo),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No se pudo actualizar: $mensaje',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () =>
                  context.read<IncidenciasBloc>().add(const CargarIncidencias()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorVacio extends StatelessWidget {
  const _ErrorVacio({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 56, color: context.legacy.rojo),
            const SizedBox(height: 14),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(),
      );
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.icono, required this.titulo, required this.mensaje});

  final IconData icono;
  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 14),
            Text(titulo, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}