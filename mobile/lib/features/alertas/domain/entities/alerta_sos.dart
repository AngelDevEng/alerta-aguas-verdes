/// Resultado de crear (o reutilizar) un SOS.
///
/// El backend devuelve la alerta con sus campos de siempre mas `sessionToken`:
/// el token anonimo que identifica al ciudadano en `GET /seguimiento` y, mas
/// adelante, en la sala `sos:{alertaId}`.
class AlertaSos {
  const AlertaSos({required this.alertaId, required this.sessionToken});

  final String alertaId;
  final String sessionToken;
}