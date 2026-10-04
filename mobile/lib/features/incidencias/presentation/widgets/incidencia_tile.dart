import 'package:flutter/material.dart';

import '../../domain/entities/incidencia.dart';
import 'incidencia_badges.dart';

/// Tarjeta de una incidencia en la lista.
class IncidenciaTile extends StatelessWidget {
  const IncidenciaTile({super.key, required this.incidencia, this.onTap});

  final Incidencia incidencia;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    incidencia.codigo.isEmpty ? 'Sin codigo' : incidencia.codigo,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  PrioridadBadge(prioridad: incidencia.prioridad),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                incidencia.tipo.isEmpty ? 'Sin tipo' : incidencia.tipo,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (incidencia.descripcion case final d? when d.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  d,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  EstadoBadge(estado: incidencia.estado),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _meta(
                      context,
                      icon: Icons.schedule,
                      texto: _fechaCorta(incidencia.ocurridoEn),
                    ),
                  ),
                  if (incidencia.evidencias > 0)
                    _meta(
                      context,
                      icon: Icons.photo_camera_outlined,
                      texto: '${incidencia.evidencias}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(
    BuildContext context, {
    required IconData icon,
    required String texto,
  }) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      );

  /// `dd/mm hh:mm`, sin dependencias de `intl` para un formato tan simple.
  static String _fechaCorta(DateTime f) {
    final d = f.day.toString().padLeft(2, '0');
    final m = f.month.toString().padLeft(2, '0');
    final h = f.hour.toString().padLeft(2, '0');
    final min = f.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }
}