import '../../../../core/storage/sos_session_store.dart';

/// Eventos del SOS.
sealed class SosEvent {
  const SosEvent();
}

/// El usuario toco el boton SOS del menu principal.
class SosSolicitado extends SosEvent {
  const SosSolicitado();
}

/// Reanuda un SOS que quedo pendiente de confirmacion (al abrir o volver a la
/// app). Reutiliza la misma `Idempotency-Key` y el mismo payload: si la central
/// no alcanzo a confirmar, el reintento no duplica la alerta.
class SosReanudarPendiente extends SosEvent {
  const SosReanudarPendiente();
}

/// Reintento interno tras el backoff. No lo dispara el usuario.
class SosReintentar extends SosEvent {
  const SosReintentar(this.pendiente);

  final PendingSos pendiente;
}

/// El usuario cancela el envio en curso desde el banner. Detiene los reintentos
/// automaticos; si ya hubo al menos un intento, el pendiente se conserva (misma
/// `Idempotency-Key`) para poder reintentar sin duplicar.
class SosCancelarEnvio extends SosEvent {
  const SosCancelarEnvio();
}