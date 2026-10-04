import 'package:flutter/material.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../unidades/domain/entities/unidad.dart';
import '../../../unidades/domain/usecases/unidad_usecases.dart';

/// Hoja de despacho: elige la unidad que se asigna a la incidencia.
///
/// Se abre como `showModalBottomSheet` porque es una eleccion pontual sobre el
/// caso que ya esta abierto, no una pantalla a la que se navega: el operador
/// entra, elige y vuelve al detalle sin perder el contexto.
///
/// El filtro por `DISPONIBLE` no se reimplementa aca. `UnidadRepository`
/// ya lo aplica, asi que si el backend agrega un estado despachable nuevo hay un
/// solo lugar que cambiar.
///
/// Falla de la lista de unidades dentro de la misma hoja, no en la pantalla
/// completa: el detalle ya esta cargado y el error es del dialogo, no de la
/// pagina.
class SelectorUnidadSheet extends StatefulWidget {
  const SelectorUnidadSheet({super.key, this.unidadActualId});

  /// Unidad ya asignada, para marcarla en la lista.
  final String? unidadActualId;

  /// Abre la hoja y devuelve el id de la unidad elegida, o null si se cancela.
  ///
  /// Devolver el id y no el dispatch es lo que permite que el llamador muestre
  /// el error de un 400 (unidad ocupada entre la lista y el clic) sin reabrir
  /// el dialogo desde adentro de esta hoja.
  static Future<String?> mostrar(
    BuildContext context, {
    String? unidadActualId,
  }) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SelectorUnidadSheet(unidadActualId: unidadActualId),
      );

  @override
  State<SelectorUnidadSheet> createState() => _SelectorUnidadSheetState();
}

class _SelectorUnidadSheetState extends State<SelectorUnidadSheet> {
  late Future<Result<List<Unidad>>> _carga;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    // Resuelto desde el locator y no por constructor: la hoja se abre desde el
    // boton del detalle, que ya esta dentro del arbol de providers, y meter un
    // provider mas solo para una consulta de lectura no aporta nada.
    _carga = sl<ListarUnidadesDespachablesUseCase>()();
  }

  void _reintentar() => setState(_cargar);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Despachar unidad', style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Solo se listan las unidades disponibles.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder<Result<List<Unidad>>>(
                future: _carga,
                builder: (context, snapshot) {
                  // FutureBuilder y no un Bloc: la hoja no comparte su estado con
                  // nadie, y un bloc propio por cada apertura seria un
                  // `BlocProvider` que nadie observa.
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  return switch (snapshot.data!) {
                    Ok<List<Unidad>>(:final value) => _Lista(
                        unidades: value,
                        actualId: widget.unidadActualId,
                      ),
                    Err<List<Unidad>>(:final failure) => _Error(
                        failure: failure,
                        onReintentar: _reintentar,
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.unidades, required this.actualId});

  final List<Unidad> unidades;
  final String? actualId;

  @override
  Widget build(BuildContext context) {
    if (unidades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'No hay unidades disponibles en este momento.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: unidades.length,
      itemBuilder: (context, i) {
        final u = unidades[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            switch (u.tipo) {
              TipoUnidad.motocicleta => Icons.two_wheeler,
              TipoUnidad.pie => Icons.directions_walk,
              _ => Icons.directions_car_outlined,
            },
          ),
          title: Text(u.etiquetaOperador),
          subtitle: Text(u.ultimaActualizacion == null
              ? u.tipo.etiqueta
              : '${u.tipo.etiqueta} · ${_hora(u.ultimaActualizacion!)}'),
          trailing: u.id == actualId
              ? Icon(Icons.check, color: context.legacy.verde)
              : null,
          // Cierra la hoja y devuelve el id: el `PATCH` lo dispara el
          // llamador, que es quien puede mostrar el error sin perder el estado.
          onTap: () => Navigator.of(context).pop(u.id),
        );
      },
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.failure, required this.onReintentar});

  final Failure failure;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.cloud_off, color: context.legacy.rojo),
          const SizedBox(height: 8),
          Text(failure.message, textAlign: TextAlign.center),
          // Un 403 aqui no mejora con reintentar: es falta de permiso.
          if (failure is! ForbiddenFailure && failure is! AuthFailure) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// `hh:mm` de la ultima posicion reportada.
///
/// Se muestra la hora y no "hace 3 h" a proposito: no hay reloj de la app que
/// sepa en que zona esta el servidor, asi que una edad calculada aca puede
/// mentir por la zona horaria sin que nada avise.
String _hora(DateTime f) =>
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
