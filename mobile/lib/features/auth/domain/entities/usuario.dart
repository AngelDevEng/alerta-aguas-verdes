/// Entidad de dominio: sesion autenticada.
///
/// No es el DTO de la API. `data/` traduce DTO -> entidad, de modo que un
/// cambio en el JSON no toque las reglas de negocio ni los widgets.
class AuthSession {
  const AuthSession({required this.usuario});

  final Usuario usuario;
}

/// Entidad de dominio: usuario en sesion.
class Usuario {
  const Usuario({
    required this.id,
    required this.dni,
    required this.nombreCompleto,
    required this.rol,
    this.email,
  });

  final String id;
  final String dni;
  final String nombreCompleto;
  final String rol;
  final String? email;

  /// Mapea a los mismos roles que valida `RolesGuard` en el backend.
  bool get esOperador => const {
        'SERENO',
        'OPERADOR',
        'ADMIN',
        'DIRECTIVO',
      }.contains(rol);

  bool get esCiudadano => !esOperador;

  @override
  bool operator ==(Object other) =>
      other is Usuario && other.id == id && other.dni == dni && other.rol == rol;

  @override
  int get hashCode => Object.hash(id, dni, rol);
}