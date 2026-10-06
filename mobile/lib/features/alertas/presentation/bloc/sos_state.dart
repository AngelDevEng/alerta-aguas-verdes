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

/// GPS + `POST /alertas` en curso.
///
/// Mientras se esta aca el boton queda deshabilitado: dos SOS simultaneos
/// crearian dos alertas criticas en la sala de operacion.
class SosEnviando extends SosState {
  const SosEnviando();
}

/// Alerta creada: "Auxilio enviado a central" (texto del legacy).
class SosEnviado extends SosState {
  const SosEnviado();
}

/// Algo fallo (GPS o red).
///
/// El mensaje viene del tipo de [Failure], nunca del texto crudo del
/// backend.
class SosError extends SosState {
  const SosError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => [mensaje];
}
