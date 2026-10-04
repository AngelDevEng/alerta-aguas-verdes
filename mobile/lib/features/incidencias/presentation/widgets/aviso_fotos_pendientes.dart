import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/reportar_state.dart';

/// Aviso de que el reporte quedo pero alguna foto fallo en subir.
///
/// La app no ofrece borrar fotos ya subidas: el backend no expone un DELETE de
/// evidencias, asi que el remedio es reintentar la subida completa. Eso justifica
/// que sea un solo boton y no un editor.
class AvisoFotosPendientes extends StatelessWidget {
  const AvisoFotosPendientes({super.key, required this.exito, required this.onReintentar});

  final ReportarExito exito;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final legacy = context.legacy;
    return Material(
      color: legacy.naranja.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 20, color: legacy.naranja),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'El reporte se guardo, pero ${exito.fotosFallidas} '
                '${exito.fotosFallidas == 1 ? "foto" : "fotos"} no se pudo subir.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
