import 'package:flutter/material.dart';

import '../bloc/reportar_state.dart';

/// Pantalla de "el reporte se esta guardando".
///
/// Reemplaza al formulario completo: enviar el mismo reporte dos veces lo
/// duplicaria, asi que el boton se esconde y la pantalla de aviso manda.
class EnvioEnCurso extends StatelessWidget {
  const EnvioEnCurso({super.key, required this.estado});

  final ReportarState estado;

  @override
  Widget build(BuildContext context) {
    final s = estado as ReportarEnviando;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 22),
            Text(s.fase.etiqueta, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: s.progreso),
            ),
            const SizedBox(height: 10),
            Text(
              'No cierres la app: el reporte ya puede estar guardandose.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
