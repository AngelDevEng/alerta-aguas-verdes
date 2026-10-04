import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/catalogo.dart';
import '../bloc/catalogos_bloc.dart';
import '../bloc/catalogos_event.dart';
import '../bloc/catalogos_state.dart';

/// Central de emergencias.
///
/// Endpoint público a propósito: los teléfonos deben estar disponibles aunque la
/// sesión haya caducado. Es el equivalente móvil de `@Public()` en NestJS.
class EmergenciasPage extends StatelessWidget {
  const EmergenciasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Central de emergencias')),
      body: BlocBuilder<CatalogosBloc, CatalogosState>(
        builder: (context, state) => switch (state) {
          CatalogosCargando() =>
            const Center(child: CircularProgressIndicator()),
          CatalogosError(:final mensaje) => _Error(mensaje: mensaje),
          CatalogosListos(:final emergencias) =>
            _Lista(emergencias: emergencias),
        },
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.emergencias});

  final List<ContactoEmergencia> emergencias;

  @override
  Widget build(BuildContext context) {
    if (emergencias.isEmpty) {
      return const Center(child: Text('No hay contactos configurados'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: emergencias.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = emergencias[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: c.esWhatsapp
                ? const Color(0xFF25D366)
                : Theme.of(context).colorScheme.errorContainer,
            child: Icon(
              c.esWhatsapp ? Icons.chat : Icons.phone_in_talk,
              color: c.esWhatsapp
                  ? Colors.white
                  : Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          title: Text(c.nombre),
          subtitle: Text(c.telefono),
          trailing: FilledButton.tonal(
            onPressed: () => _llamar(context, c),
            child: Text(c.esWhatsapp ? 'WhatsApp' : 'Llamar'),
          ),
        );
      },
    );
  }

  void _llamar(BuildContext context, ContactoEmergencia c) {
    final uri = c.esWhatsapp
        ? Uri.parse('https://wa.me/${c.telefonoInternacional.replaceAll('+', '')}')
        : Uri.parse('tel:${c.telefonoInternacional}');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => context
                  .read<CatalogosBloc>()
                  .add(const CargarEmergencias()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}