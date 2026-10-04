import 'package:flutter/material.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Tarjeta con la ubicacion del reporte.
///
/// Tres estados: ubicando la primera vez, sin ubicacion (error o denegado) y
/// obtenida. El ultimo muestra ademas el lugar aproximado resuelto por
/// geocoding inverso.
class TarjetaUbicacion extends StatelessWidget {
  const TarjetaUbicacion({
    super.key,
    required this.posicion,
    required this.ubicando,
    required this.onActualizar,
    required this.lugarDe,
  });

  final PosicionActual? posicion;
  final bool ubicando;
  final VoidCallback onActualizar;
  final Future<String> Function(PosicionActual) lugarDe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = posicion;

    if (ubicando && p == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 14),
              Text('Obteniendo ubicacion...'),
            ],
          ),
        ),
      );
    }

    if (p == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sin ubicacion. El reporte no se puede enviar sin ella.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: ubicando ? null : onActualizar,
                icon: const Icon(Icons.my_location),
                label: const Text('Obtener ubicacion'),
              ),
            ],
          ),
        ),
      );
    }

    // El lugar se resuelve aparte porque geocoding inverso va por red y no debe
    // bloquear el render de la tarjeta.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: context.legacy.verde),
                const SizedBox(width: 8),
                Text('Ubicacion obtenida', style: theme.textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: ubicando ? null : onActualizar,
                  icon: ubicando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${p.latitud.toStringAsFixed(6)}, ${p.longitud.toStringAsFixed(6)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Precision: ${p.precisionLegible}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            LugarNombre(posicion: p, lugarDe: lugarDe),
          ],
        ),
      ),
    );
  }
}

/// Nombre legible de la ubicacion, resuelto por geocoding inverso.
///
/// Widget con estado propio para no refetchear en cada rebuild del padre: el
/// padre se reconstruye con cada tecla y a cada rebuild no le corresponde una
/// llamada de red.
class LugarNombre extends StatefulWidget {
  const LugarNombre({super.key, required this.posicion, required this.lugarDe});

  final PosicionActual posicion;
  final Future<String> Function(PosicionActual) lugarDe;

  @override
  State<LugarNombre> createState() => _LugarNombreState();
}

class _LugarNombreState extends State<LugarNombre> {
  late Future<String> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = widget.lugarDe(widget.posicion);
  }

  @override
  void didUpdateWidget(LugarNombre oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cambiar de posicion cambia el lugar: hay que volver a preguntar.
    if (oldWidget.posicion.latitud != widget.posicion.latitud ||
        oldWidget.posicion.longitud != widget.posicion.longitud) {
      _futuro = widget.lugarDe(widget.posicion);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _futuro,
      builder: (context, snap) {
        final lugar = snap.data;
        if (lugar == null || lugar.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            lugar,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        );
      },
    );
  }
}
