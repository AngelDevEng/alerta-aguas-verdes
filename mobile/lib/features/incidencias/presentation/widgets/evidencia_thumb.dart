import 'dart:io';

import 'package:flutter/material.dart';

/// Miniatura de una foto adjunta, con boton para quitarla.
///
/// Usa [Image.file] con la ruta local que devuelve `image_picker`. No se
/// cargan bytes a memoria: Flutter decodifica en el tamano exacto que se pide,
/// asi que una foto de 8 MP no se vuelve un bitmap de 32 MB.
class EvidenciaThumb extends StatelessWidget {
  const EvidenciaThumb({super.key, required this.ruta, required this.onQuitar});

  final String ruta;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(ruta),
              fit: BoxFit.cover,
              // Si el usuario borro la foto entre elegirla y enviar, o el
              // archivo quedo corrupto, se muestra un marcador en vez de un
              // error rojo dentro de un espacio de 84 px.
              errorBuilder: (context, error, stack) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, color: scheme.outline),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onQuitar,
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
