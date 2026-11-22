import 'package:equatable/equatable.dart';

/// Estados del envio de SOS.
sealed class SosState extends Equatable {
  const SosState();

  @override
  List<Object?> get props => const [];
}

/// Sin envio en curso. Estado de arranque.
class SosInicial extends SosState {
  const SosInicial();
}

/// GPS + `POST /alertas` en curso (o reintento inmediato).
///
/// Mientras se esta aca el boton queda deshabilitado: dos SOS simultaneos
/// crearian dos alertas criticas en la sala de operacion.
class SosEnviando extends SosState {
  const SosEnviando();
}

/// La alerta no se pudo confirmar y se esta reintentando con backoff.
///
/// Es un estado persistente (no un snackbar): el usuario debe ver que su SOS
/// sigue en curso aunque la red este caida. El pendiente se conserva para que
/// el reintento reutilice la misma `Idempotency-Key`.
class SosConectandoCentral extends SosState {
  const SosConectandoCentral();
}

/// Alerta creada: "Auxilio enviado a central" (texto del legacy).
///
/// `alertaId` y `sessionToken` son lo que el ciudadano necesita para volver a
/// entrar a su seguimiento aunque cierre la app: se guardan en almacenamiento
/// seguro aparte del JWT.
class SosEnviado extends SosState {
  const SosEnviado({required this.alertaId, this.sessionToken});
  final String alertaId;
  final String? sessionToken;
  @override
  List<Object?> get props => [alertaId, sessionToken];
}

/// La alerta ya cerro (reintento idempotente de una alerta terminal). No hay
/// token: se limpia la sesion y se avisa que ya fue atendida.
class SosFinalizada extends SosState {
  const SosFinalizada({required this.alertaId, this.estado});
  final String alertaId;
  final String? estado;
  @override
  List<Object?> get props => [alertaId, estado];
}

/// Algo fallo de forma no reintentable (GPS sin ubicacion es un envio, no un
/// error; 429, validacion, etc. si lo son).
///
/// El mensaje viene del tipo de [Failure], nunca del texto crudo del backend.
/// La UI siempre ofrece "Llamar ahora" ante este estado.
class SosError extends SosState {
  const SosError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => [mensaje];
}

/// El usuario cancelo el envio en curso. Los reintentos automaticos se
/// detuvieron, las respuestas en vuelo se ignoran y el pendiente se borro: al
/// reabrir la app no se reenvia. Si ya hubo un intento, solo la
/// `Idempotency-Key` quedo guardada para la cancelacion en servidor (Fase 1).
class SosCancelado extends SosState {
  const SosCancelado();
}