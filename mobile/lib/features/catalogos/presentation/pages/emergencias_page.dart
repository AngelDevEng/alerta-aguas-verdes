import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../mapa/presentation/mapa_calor_page.dart';
import '../../domain/entities/catalogo.dart';
import '../bloc/catalogos_bloc.dart';
import '../bloc/catalogos_event.dart';
import '../bloc/catalogos_state.dart';

/// Pantalla de contactos de emergencia, 1:1 con la app original.
///
/// Grilla de 2 columnas con tarjetas blancas, esquinas redondeadas, sombra
/// suave, ícono/imagen centrado arriba y título centrado abajo.
/// Al tocar una tarjeta: llama, abre WhatsApp o abre el mapa de calor.
class EmergenciasPage extends StatelessWidget {
  const EmergenciasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFADC8E8), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: BlocBuilder<CatalogosBloc, CatalogosState>(
                  builder: (context, state) => switch (state) {
                    CatalogosCargando() =>
                      const Center(child: CircularProgressIndicator()),
                    CatalogosError(:final mensaje) => _Error(mensaje: mensaje),
                    CatalogosListos(:final emergencias) =>
                      _Grilla(emergencias: emergencias),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header: escudo + "ALERTA" / "AGUAS VERDES" + campana + subtítulo.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Image.asset(
            'assets/images/escudo.webp',
            width: 56,
            height: 64,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ALERTA',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B1B45),
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Image.asset(
                          'assets/images/logomuni.png',
                          width: 40,
                          height: 40,
                          gaplessPlayback: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'AGUAS VERDES',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Color(0xFF1B1B45)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// Subtítulo centrado: "CONTACTOS DE EMERGENCIA".
class _Subtitulo extends StatelessWidget {
  const _Subtitulo();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'CONTACTOS DE EMERGENCIA',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF555555),
          letterSpacing: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Grilla de 2 columnas con tarjetas.
class _Grilla extends StatelessWidget {
  const _Grilla({required this.emergencias});

  final List<ContactoEmergencia> emergencias;

  @override
  Widget build(BuildContext context) {
    if (emergencias.isEmpty) {
      return const Center(child: Text('No hay contactos configurados'));
    }
    return Column(
      children: [
        const _Subtitulo(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: emergencias.length + 1,
            itemBuilder: (context, i) {
              if (i == emergencias.length) return const _TarjetaMapaCalor();
              final c = emergencias[i];
              return _TarjetaContacto(contacto: c);
            },
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de contacto individual.
class _TarjetaContacto extends StatelessWidget {
  const _TarjetaContacto({required this.contacto});

  final ContactoEmergencia contacto;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _accion(context, contacto),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: _ImagenContacto(contacto: contacto),
              ),
              const SizedBox(height: 4),
              Text(
                contacto.nombre.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _accion(BuildContext context, ContactoEmergencia c) {
    final uri = c.esWhatsapp
        ? Uri.parse('https://wa.me/${c.telefonoInternacional.replaceAll('+', '')}')
        : Uri.parse('tel:${c.telefonoInternacional}');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Imagen del contacto: usa un ícono local según categoría, con fallback.
class _ImagenContacto extends StatelessWidget {
  const _ImagenContacto({required this.contacto});

  final ContactoEmergencia contacto;

  @override
  Widget build(BuildContext context) {
    final nombre = contacto.nombre.toLowerCase();

    // Selecciona ícono local según palabras clave del nombre.
    String asset;
    if (nombre.contains('bomber')) {
      asset = 'assets/images/ic_otras_emergencias.webp';
    } else if (nombre.contains('mujer') || nombre.contains('cem')) {
      asset = 'assets/images/emergencia.png';
    } else if (nombre.contains('subprefect')) {
      asset = 'assets/images/ic_comisaria.webp';
    } else if (nombre.contains('salud') || nombre.contains('hospital')) {
      asset = 'assets/images/emergencia.png';
    } else if (contacto.esWhatsapp || nombre.contains('serenazgo')) {
      asset = 'assets/images/ic_serenazgo.webp';
    } else if (nombre.contains('incidencia')) {
      asset = 'assets/images/ic_incidencia.webp';
    } else {
      asset = 'assets/images/emergencia.png';
    }

    return Image.asset(
      asset,
      width: double.infinity,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const Icon(
        Icons.emergency,
        size: 48,
        color: Color(0xFFD32F2F),
      ),
    );
  }
}

/// Tarjeta del Mapa de Calor.
class _TarjetaMapaCalor extends StatelessWidget {
  const _TarjetaMapaCalor();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MapaCalorPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: Image.asset(
                  'assets/images/ubicacion.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.map,
                    size: 48,
                    color: Color(0xFFFF9800),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'MAPA DE CALOR',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de error con reintento.
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