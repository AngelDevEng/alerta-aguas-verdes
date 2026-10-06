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

  // Roles tal como los define `RolesGuard`. Vive en una sola constante porque
  // cada capacidad de la app los compara y duplicar las listas es como aparecen
  // permisos que el backend no tiene.
  static const _operadores = {'SERENO', 'OPERADOR', 'ADMIN', 'DIRECTIVO'};
  static const _cambianEstado = {'SERENO', 'OPERADOR', 'ADMIN'};
  static const _despachan = {'OPERADOR', 'ADMIN'};

  /// Cualquiera que entra a la parte operativa del sistema.
  ///
  /// Equivale a `esOperador` del legacy: un `CIUDADANO` es todo lo que no entra
  /// en esta lista.
  bool get esOperador => _operadores.contains(rol);

  bool get esCiudadano => !esOperador;

  /// Si puede abrir el detalle de una incidencia (`GET /incidencias/:id`).
  ///
  /// Importa la distincion con [puedeReportar]: un ciudadano reporta pero no ve
  /// el detalle de lo que reporto. Es una decision del backend, no una
  /// limitacion que se pueda sortear desde la app.
  bool get puedeVerDetalle => esOperador;

  /// Si es sereno: equivale al rol `PATRULLERO` del legacy.
  ///
  /// El menu principal le muestra el panel de patrulla (placa + rastreo) y
  /// oculta SOS/Emergencia, igual que `MenuActivity.configurarVisibilidadSegunRol`.
  bool get esSereno => rol == 'SERENO';

  /// Si puede avanzar el estado (`PATCH /incidencias/:id/estado`).
  ///
  /// Un `DIRECTIVO` queda fuera: ve todos los casos pero no los despacha.
  bool get puedeCambiarEstado => _cambianEstado.contains(rol);

  /// Si puede asignar una unidad (`PATCH /incidencias/:id/asignar`).
  ///
  /// Mas restrictivo que [puedeCambiarEstado] a proposito: despachar es decision
  /// del operador, un sereno avanza el estado del caso que ya se le asigno.
  bool get puedeDespachar => _despachan.contains(rol);

  @override
  bool operator ==(Object other) =>
      other is Usuario && other.id == id && other.dni == dni && other.rol == rol;

  @override
  int get hashCode => Object.hash(id, dni, rol);
}