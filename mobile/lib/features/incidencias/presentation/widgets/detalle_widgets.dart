import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/detalle_incidencia.dart';
import '../../domain/entities/evidencia.dart';
import '../../domain/entities/incidencia.dart';
import 'incidencia_badges.dart';

/// Cabecera del detalle: codigo, tipo, estado y prioridad.
class DetalleCabecera extends StatelessWidget {
  const DetalleCabecera({super.key, required this.incidencia});

  final Incidencia incidencia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              incidencia.codigo.isEmpty ? 'Sin codigo' : incidencia.codigo,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            PrioridadBadge(prioridad: incidencia.prioridad),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          incidencia.tipo.isEmpty ? 'Sin tipo' : incidencia.tipo,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            EstadoBadge(estado: incidencia.estado),
            const SizedBox(width: 8),
            if (incidencia.evidencias > 0)
              _Contador(
                icono: Icons.photo_camera_outlined,
                texto: '${incidencia.evidencias}',
              ),
            const Spacer(),
            Text(
              _fechaLarga(incidencia.ocurridoEn),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bloque de datos del reporte: descripcion, referencia, lugar y autores.
class DetalleDatos extends StatelessWidget {
  const DetalleDatos({super.key, required this.incidencia});

  final Incidencia incidencia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Seccion(titulo: 'Descripcion'),
        if (incidencia.descripcion case final d? when d.isNotEmpty)
          Text(d, style: tema.textTheme.bodyMedium)
        else
          Text(
            'El reporte no incluye descripcion.',
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        if (incidencia.referencia case final r? when r.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Dato(etiqueta: 'Referencia', valor: r),
        ],
        _Dato(
          etiqueta: 'Reporta',
          valor: incidencia.reportadoPorNombre ?? 'Cuenta sin nombre',
        ),
        _Dato(
          etiqueta: 'Ubicacion',
          valor: '${incidencia.latitud.toStringAsFixed(5)}, '
              '${incidencia.longitud.toStringAsFixed(5)}',
        ),
        if (incidencia.atendidoEn case final a?)
          _Dato(etiqueta: 'Atendida', valor: _fechaLarga(a)),
      ],
    );
  }
}

/// Lista de evidencias del reporte.
///
/// No se puede mostrar una miniatura sin verificar el MIME: el bucket de
/// Supabase entrega lo que tenga configurado y un 403 en la imagen se ve igual
/// que un archivo roto. Un archivo de audio sin icono de imagen es mejor que
/// un cuadro gris sin explicacion.
class DetalleEvidencias extends StatelessWidget {
  const DetalleEvidencias({super.key, required this.evidencias});

  final List<Evidencia> evidencias;

  @override
  Widget build(BuildContext context) {
    if (evidencias.isEmpty) {
      return _Seccion(
        titulo: 'Evidencias',
        hijo: Text(
          'No hay fotos ni archivos adjuntos.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
        ),
      );
    }

    return _Seccion(
      titulo: 'Evidencias (${evidencias.length})',
      hijo: Column(
        children: [
          for (final e in evidencias) _EvidenciaTile(evidencia: e),
        ],
      ),
    );
  }
}

class _EvidenciaTile extends StatelessWidget {
  const _EvidenciaTile({required this.evidencia});

  final Evidencia evidencia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icono = switch (evidencia) {
      _ when evidencia.esVideo => Icons.videocam_outlined,
      _ when evidencia.esAudio => Icons.graphic_eq,
      _ => Icons.photo_outlined,
    };

    // Sin fecha de captura no se inventa ninguna: el `RETURNING` del alta de
    // evidencia la trae, pero un registro viejo puede no tenerla.
    final capturado = evidencia.capturadoEn;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono, color: theme.colorScheme.onSurfaceVariant),
      title: Text(evidencia.etiqueta),
      subtitle: capturado == null
          ? null
          : Text(_fechaLarga(capturado), style: theme.textTheme.bodySmall),
      trailing: evidencia.esImagen
          // La URL va como dato, no como boton: para abrirla hace falta una
          // decision de permisos (bucket publico o sesion) que todavia no esta
          // tomada. Decirlo aca es mejor que un icono que no hace nada.
          ? Icon(Icons.link, size: 18, color: theme.colorScheme.outline)
          : null,
    );
  }
}

/// Historial de cambios de estado, del mas reciente al mas antiguo.
///
/// El backend lo devuelve en orden ascendente; se da vuelta para que lo que
/// paso ultimo quede arriba, que es lo que se busca al abrir un caso.
class DetalleHistorial extends StatelessWidget {
  const DetalleHistorial({super.key, required this.historial});

  final List<MovimientoEstado> historial;

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final ordenados = historial.reversed.toList(growable: false);

    return _Seccion(
      titulo: 'Historial',
      hijo: Column(
        children: [
          for (var i = 0; i < ordenados.length; i++)
            _MovimientoTile(
              movimiento: ordenados[i],
              esUltimo: i == ordenados.length - 1,
              separador: theme.colorScheme.outlineVariant,
            ),
        ],
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({
    required this.movimiento,
    required this.esUltimo,
    required this.separador,
  });

  final MovimientoEstado movimiento;
  final bool esUltimo;
  final Color separador;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sin `IntrinsicHeight`: la linea del tiempo no necesita ocupar el alto de
    // la fila, y medir el alto intrinseco de una columna con `Expanded` obliga a
    // Flutter a relajar el layout en cada item de la lista.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: esUltimo
                    ? context.legacy.verde
                    : theme.colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
            if (!esUltimo)
              Container(
                width: 1,
                height: 44,
                color: separador,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movimiento.resumen,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${movimiento.autor} · ${_fechaLarga(movimiento.registradoEn)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra de acciones de despacho.
///
/// Que botones aparezcan depende de dos cosas distintas y ambas estan en el
/// backend, no aca: el estado actual (que transiciones tienen sentido) y el rol
/// (quien puede despachar). Ver el detalle de permisos en
/// `IncidenciaRemoteDataSource`.
class DetalleAcciones extends StatelessWidget {
  const DetalleAcciones({
    super.key,
    required this.estado,
    required this.puedeAsignar,
    required this.puedeCambiarEstado,
    required this.enCurso,
    required this.onEstado,
    required this.onAsignar,
  });

  final EstadoIncidencia estado;
  final bool puedeAsignar;
  final bool puedeCambiarEstado;
  final bool enCurso;

  final ValueChanged<EstadoIncidencia> onEstado;
  final VoidCallback onAsignar;

  @override
  Widget build(BuildContext context) {
    final siguiente = estado.siguientesPosibles;
    final puedeHacerAlgo =
        puedeAsignar || (puedeCambiarEstado && siguiente.isNotEmpty);

    // Sin nada que hacer se oculta la barra entera en vez de mostrar un boton
    // deshabilitado: un caso cerrado con un boton gris encima no explica nada.
    if (!puedeHacerAlgo) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (puedeAsignar)
          FilledButton.icon(
            onPressed: enCurso ? null : onAsignar,
            icon: enCurso
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.directions_car_outlined),
            label: const Text('Despachar unidad'),
          ),
        if (puedeAsignar && puedeCambiarEstado && siguiente.isNotEmpty)
          const SizedBox(height: 8),
        if (puedeCambiarEstado && siguiente.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in siguiente)
                OutlinedButton(
                  onPressed: enCurso ? null : () => onEstado(e),
                  child: Text(e.etiqueta),
                ),
            ],
          ),
      ],
    );
  }
}

/// Estado vacio de la seccion de evidencias/historial.
class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, this.hijo});

  final String titulo;
  final Widget? hijo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ?hijo,
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              etiqueta,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(valor, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(texto, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// `dd/mm/yyyy hh:mm`. Sin `intl` porque no hay mas que formatear.
String _fechaLarga(DateTime f) {
  final d = f.day.toString().padLeft(2, '0');
  final m = f.month.toString().padLeft(2, '0');
  final y = f.year;
  final h = f.hour.toString().padLeft(2, '0');
  final min = f.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $h:$min';
}

/// Aviso de error a pantalla completa, para cuando no hay detalle que conservar.
class DetalleErrorTotal extends StatelessWidget {
  const DetalleErrorTotal({super.key, required this.failure, required this.onReintentar});

  final Failure failure;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    // Un 403 aqui no es un problema de la app: el rol no puede ver el detalle y
    // tiene su propio mensaje, sin un "reintentar" que no va a cambiar nada.
    final esPermiso = failure is ForbiddenFailure;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              esPermiso ? Icons.lock_outline : Icons.cloud_off,
              size: 56,
              color: context.legacy.rojo,
            ),
            const SizedBox(height: 14),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (!esPermiso) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}