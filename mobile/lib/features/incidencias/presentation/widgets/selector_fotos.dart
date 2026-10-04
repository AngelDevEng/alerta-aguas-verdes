import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constantes_reporte.dart';
import 'evidencia_thumb.dart';

/// Selector de fotos del reporte: camara y galeria, con miniaturas.
///
/// Las miniaturas son `EvidenciaThumb`, que ya gestiona el error de una imagen
/// corrupta: este widget no se entera, y un thumb roto no tira el selector.
class SelectorFotos extends StatelessWidget {
  const SelectorFotos({
    super.key,
    required this.fotos,
    required this.onCamara,
    required this.onGaleria,
    required this.onQuitar,
  });

  final List<XFile> fotos;
  final VoidCallback onCamara;
  final VoidCallback onGaleria;
  final ValueChanged<int> onQuitar;

  @override
  Widget build(BuildContext context) {
    final completo = fotos.length >= kMaxFotosReporte;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fotos.isEmpty)
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onCamara,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camara'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onGaleria,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeria'),
              ),
            ],
          )
        else ...[
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fotos.length + (completo ? 0 : 1),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == fotos.length) {
                  return BotonAgregar(icon: Icons.add, onTap: onCamara);
                }
                return EvidenciaThumb(
                  ruta: fotos[i].path,
                  onQuitar: () => onQuitar(i),
                );
              },
            ),
          ),
          if (!completo) ...[
            const SizedBox(height: 8),
            Text(
              '${fotos.length} de $kMaxFotosReporte fotos',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Boton cuadrado para agregar una foto mas.
class BotonAgregar extends StatelessWidget {
  const BotonAgregar({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
