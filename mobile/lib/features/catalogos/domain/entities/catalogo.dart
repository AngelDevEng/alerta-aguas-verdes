/// Entidad de dominio: contacto de la central telefónica.
///
/// No sabe nada de HTTP ni de si es WhatsApp: eso último es solo como se
/// presenta. Aquí solo hay el hecho de que existe un teléfono.
class ContactoEmergencia {
  const ContactoEmergencia({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.esWhatsapp,
  });

  final int id;
  final String nombre;
  final String telefono;
  final bool esWhatsapp;

  /// Teléfono en formato internacional, como espera `tel:` y `wa.me`.
  ///
  /// Los phones seeded empiezan con 51 (Perú). Si algún contacto viniera sin
  /// prefijo, se asume Perú: es el único país que opera esta municipalidad.
  String get telefonoInternacional {
    final limpio = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    if (limpio.startsWith('+')) return limpio;
    if (limpio.length == 9) return '+51$limpio';
    return limpio;
  }
}

/// Entidad de dominio: asociación de vivienda.
class Asociacion {
  const Asociacion({required this.id, required this.nombre});

  final int id;
  final String nombre;
}