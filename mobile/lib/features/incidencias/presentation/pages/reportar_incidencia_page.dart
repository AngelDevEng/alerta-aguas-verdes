import 'package:flutter/material.dart';

/// Pendiente: formulario de reporte con GPS, foto y nivel de urgencia.
///
/// Consumirá `POST /incidencias` (`CreateIncidenciaDto`) y
/// `POST /incidencias/:id/evidencias`.
class ReportarIncidenciaPage extends StatelessWidget {
  const ReportarIncidenciaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar incidencia')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Siguiente iteracion: formulario con geolocator, image_picker y '
            'POST /incidencias. El ciudadano puede reportar sin operacion previa.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}