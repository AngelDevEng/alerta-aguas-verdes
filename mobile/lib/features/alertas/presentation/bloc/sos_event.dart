/// Eventos del SOS.
sealed class SosEvent {
  const SosEvent();
}

/// El usuario toco el boton SOS del menu principal.
class SosSolicitado extends SosEvent {
  const SosSolicitado();
}
