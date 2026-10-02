import 'package:flutter/material.dart';

/// Pendiente: lista de incidencias con filtros por estado/fecha.
class IncidenciasPage extends StatelessWidget {
  const IncidenciasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incidencias')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Siguiente iteracion: GET /incidencias con filtros estado/tipo/fecha.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}