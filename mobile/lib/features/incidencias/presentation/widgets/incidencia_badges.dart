import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/incidencia.dart';

/// Pastilla con el estado de la incidencia.
///
/// Los colores son codigo de operacion: un despachada tiene que reconocerse de
/// un vistazo sin leer el texto. Por eso el color sale de [ColoresLegacy] y no
/// del color scheme, que cambiaria de significado entre tema claro y oscuro.
class EstadoBadge extends StatelessWidget {
  const EstadoBadge({super.key, required this.estado});

  final EstadoIncidencia estado;

  @override
  Widget build(BuildContext context) {
    final legacy = context.legacy;
    final scheme = Theme.of(context).colorScheme;

    final color = switch (estado) {
      EstadoIncidencia.registrada => legacy.azul,
      EstadoIncidencia.despachada => legacy.naranja,
      EstadoIncidencia.enAtencion => legacy.amarillo,
      EstadoIncidencia.atendida => legacy.verde,
      EstadoIncidencia.cancelada => legacy.gris,
      EstadoIncidencia.unknown => scheme.outline,
    };

    // El amarillo de marca es claro; sobre el se necesita texto oscuro para
    // mantener el contraste.
    final textoSobre = estado == EstadoIncidencia.enAtencion
        ? Colors.black87
        : legibleSobre(color);

    return _Pastilla(color: color, texto: estado.etiqueta, colorTexto: textoSobre);
  }
}

/// Pastilla con la prioridad.
class PrioridadBadge extends StatelessWidget {
  const PrioridadBadge({super.key, required this.prioridad});

  final Prioridad prioridad;

  @override
  Widget build(BuildContext context) {
    final legacy = context.legacy;
    final scheme = Theme.of(context).colorScheme;

    final color = switch (prioridad) {
      Prioridad.critica => legacy.rojo,
      Prioridad.alta => legacy.naranja,
      Prioridad.media => legacy.azul,
      Prioridad.baja => legacy.gris,
      Prioridad.unknown => scheme.outline,
    };

    return _Pastilla(
      color: color,
      texto: prioridad.etiqueta,
      colorTexto: legibleSobre(color),
      esContorno: true,
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({
    required this.color,
    required this.texto,
    required this.colorTexto,
    this.esContorno = false,
  });

  final Color color;
  final String texto;
  final Color colorTexto;
  final bool esContorno;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: esContorno ? color.withValues(alpha: 0.14) : color,
        borderRadius: BorderRadius.circular(20),
        border: esContorno ? Border.all(color: color.withValues(alpha: 0.55)) : null,
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: esContorno ? color : colorTexto,
        ),
      ),
    );
  }
}

/// Negro o blanco segun la luminancia del fondo.
///
/// Sin esto, el blanco queda ilegible sobre el amarillo o el naranja de la
/// paleta legacy.
Color legibleSobre(Color fondo) =>
    fondo.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;