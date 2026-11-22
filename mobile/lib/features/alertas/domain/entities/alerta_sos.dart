/// Resultado de crear (o reutilizar) un SOS.
///
/// El backend devuelve la alerta con sus campos de siempre mas `sessionToken`:
/// el token anonimo que identifica al ciudadano en `GET /seguimiento` y, mas
/// adelante, en la sala `sos:{alertaId}`.
///
/// [sessionToken] es opcional: cuando la alerta ya cerro (reintento idempotente
/// de una alerta terminal) el backend responde sin token, solo con su [estado].
///
/// [sinUbicacion] indica que el SOS se creo sin coordenadas (GPS fallo): la
/// central debe llamar al ciudadano en vez de ir a un punto.
class AlertaSos {
  const AlertaSos({
    required this.alertaId,
    this.sessionToken,
    this.estado,
    this.sinUbicacion = false,
  });

  final String alertaId;
  final String? sessionToken;
  final String? estado;
  final bool sinUbicacion;

  bool get tieneToken => sessionToken != null && sessionToken!.isNotEmpty;

  /// Estados a partir de los cuales la alerta ya no admite seguimiento.
  bool get esTerminal =>
      const {'ATENDIDA', 'CANCELADA', 'FALSA', 'EXPIRADA'}.contains(estado);
}