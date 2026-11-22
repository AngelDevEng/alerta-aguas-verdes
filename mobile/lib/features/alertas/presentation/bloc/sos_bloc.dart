import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../../../core/idempotency/idempotency_key.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/storage/sos_session_store.dart';
import '../../domain/entities/alerta_sos.dart';
import '../../domain/usecases/alerta_usecases.dart';
import 'sos_event.dart';
import 'sos_state.dart';

/// ViewModel del boton SOS.
///
/// Orquesta el envio de una SOS con tres garantias que el legacy no tenia:
///
/// 1. **Idempotencia**: cada SOS tiene una `Idempotency-Key` estable. Un
///    reintento (mala señal, timeout, reanudar la app) reutiliza la MISMA clave
///    y el MISMO payload, asi que el backend devuelve la alerta ya creada en
///    vez de duplicarla.
/// 2. **Reintento con backoff**: si la central no responde, el estado pasa a
///    [SosConectandoCentral] y se reintenta 2, 4, 8, 16 y 30 s. El pendiente se
///    conserva para que el reintento no pierda la clave.
/// 3. **Sin ubicacion**: si el GPS falla, la SOS se envia IGUAL marcada como
///    "sin ubicacion". Perder el aviso es peor que no tener coordenadas.
///
/// El bloc es un singleton de aplicacion (ver `injector.dart`): los reintentos
/// sobreviven a que el `home_page` se desmonte, y al abrir/resumir la app se
/// despacha [SosReanudarPendiente].
class SosBloc extends Bloc<SosEvent, SosState> {
  SosBloc(this._location, this._enviar, this._store) : super(const SosInicial()) {
    on<SosSolicitado>(_onSolicitado);
    on<SosReanudarPendiente>(_onReanudar);
    on<SosReintentar>(_onReintentar);
    on<SosCancelarEnvio>(_onCancelar);
  }

  final LocationService _location;
  final EnviarSosUseCase _enviar;
  final SosStore _store;

  /// Backoff entre reintentos. Se agota tras cinco reintentos; despues se pide
  /// al usuario reintentar o llamar, conservando el pendiente.
  static const List<Duration> _backoff = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  Timer? _timer;
  int _intentos = 0;

  /// Ultimo pendiente en curso. Se conserva en memoria para que [SosCancelarEnvio]
  /// sepa que clave copiar antes de borrar el pendiente de disco.
  PendingSos? _pendiente;

  /// true si al menos un intento ya salio a la red. Solo entonces tiene sentido
  /// guardar la clave para la cancelacion en servidor de la Fase 1.
  bool _huboIntento = false;

  /// Marcador de cancelacion. Se incrementa al cancelar; un envio en vuelo que
  /// capture un valor distinto al volver se descarta (respuesta tardia).
  int _generacion = 0;

  Future<void> _onSolicitado(
    SosSolicitado event,
    Emitter<SosState> emit,
  ) async {
    // Guarda anti doble tap. `emit` actualiza el estado de forma sincronica,
    // asi que un segundo toque (evento concurrente) ve [SosEnviando] y sale.
    if (state is SosEnviando || state is SosConectandoCentral) return;

    _timer?.cancel();
    _intentos = 0;
    _huboIntento = false;
    emit(const SosEnviando());

    final pendiente = await _pendienteParaEnviar();
    if (isClosed) return;
    await _enviarPendiente(pendiente, emit);
  }

  Future<void> _onReanudar(
    SosReanudarPendiente event,
    Emitter<SosState> emit,
  ) async {
    if (state is SosEnviando || state is SosConectandoCentral) return;
    final pendiente = await _leerPendiente();
    if (pendiente == null) {
      // No habia pendiente, o expiro (TTL de 5 min). Si expiraron, avisamos
      // para que el usuario sepa que su SOS no se envio y debe llamar.
      if (await _huboPendienteExpirado()) {
        emit(const SosError('No se pudo enviar, llama ahora al serenazgo.'));
      }
      return;
    }
    if (isClosed) return;

    _timer?.cancel();
    _intentos = 0;
    _huboIntento = false;
    emit(const SosEnviando());
    await _enviarPendiente(pendiente, emit);
  }

  Future<void> _onReintentar(
    SosReintentar event,
    Emitter<SosState> emit,
  ) async {
    emit(const SosEnviando());
    if (isClosed) return;
    await _enviarPendiente(event.pendiente, emit);
  }

  /// Cancela el envio en curso.
  ///
  /// - Invalida cualquier respuesta en vuelo (marcador [_generacion]).
  /// - Borra el pendiente: al reabrir la app NO se reenvia.
  /// - Si ya hubo al menos un intento, guarda aparte SOLO la
  ///   `Idempotency-Key` para que la Fase 1 pueda cancelar la alerta en el
  ///   servidor. El payload (posicion, telefono) no se conserva.
  Future<void> _onCancelar(
    SosCancelarEnvio event,
    Emitter<SosState> emit,
  ) async {
    _generacion++;
    _timer?.cancel();
    _timer = null;

    final pendiente = _pendiente;
    if (_huboIntento && pendiente != null) {
      try {
        await _store.saveClaveCancelada(pendiente.idempotencyKey);
      } catch (_) {
        // Sin almacenamiento seguro disponible: se cancela igual.
      }
    }
    await _descartarPendiente();
    _pendiente = null;
    emit(const SosCancelado());
  }

  /// Reutiliza el pendiente si existe (misma clave y payload); si no, crea uno
  /// nuevo leyendo el GPS. Si el GPS falla, se envia sin ubicacion.
  Future<PendingSos> _pendienteParaEnviar() async {
    final existente = await _leerPendiente();
    if (existente != null) {
      _pendiente = existente;
      return existente;
    }

    final posicion = await _location.posicionActual();
    final PosicionActual? valor = switch (posicion) {
      Ok(:final value) => value,
      Err() => null,
    };

    final pendiente = PendingSos(
      idempotencyKey: nuevoIdempotencyKey(),
      latitud: valor?.latitud ?? 0,
      longitud: valor?.longitud ?? 0,
      precisionM: valor?.precisionMetros,
      sinUbicacion: valor == null,
    );
    // SOS nueva: la clave de una cancelacion anterior ya no aplica.
    await _descartarClaveCancelada();
    _pendiente = pendiente;
    await _guardarPendiente(pendiente);
    return pendiente;
  }

  Future<void> _enviarPendiente(
    PendingSos pendiente,
    Emitter<SosState> emit,
  ) async {
    _pendiente = pendiente;
    final generacion = _generacion;
    _huboIntento = true;

    final r = await _enviar(
      latitud: pendiente.latitud,
      longitud: pendiente.longitud,
      precisionM: pendiente.precisionM,
      sinUbicacion: pendiente.sinUbicacion,
      idempotencyKey: pendiente.idempotencyKey,
    );
    // Respuesta tardia de un envio cancelado: se ignora (no navega ni confirma).
    if (isClosed || generacion != _generacion) return;

    switch (r) {
      case Err(:final failure):
        // 429 no se reintenta automaticamente (evita que un bucle de reintentos
        // evada el rate limit): se limpia el pendiente y se avisa. El resto de
        // fallos reintentables conservan la misma clave y siguen con backoff.
        if (failure.reintentable && failure is! RateLimitedFailure) {
          _programarReintento(pendiente, emit);
        } else {
          await _descartarPendiente();
          await _descartarClaveCancelada();
          emit(SosError(failure.message));
        }
      case Ok(:final value):
        await _completar(value, emit);
    }
  }

  Future<void> _completar(AlertaSos value, Emitter<SosState> emit) async {
    if (value.tieneToken) {
      await _descartarPendiente();
      await _descartarClaveCancelada();
      _pendiente = null;
      await _guardarSesion(value.alertaId, value.sessionToken!);
      emit(SosEnviado(alertaId: value.alertaId, sessionToken: value.sessionToken));
      return;
    }

    if (value.esTerminal) {
      await _descartarPendiente();
      await _descartarClaveCancelada();
      _pendiente = null;
      await _descartarSesion();
      emit(SosFinalizada(alertaId: value.alertaId, estado: value.estado));
      return;
    }

    // Respuesta sin token y sin estado terminal (no deberia pasar): se trata
    // como enviada sin token.
    await _descartarPendiente();
    await _descartarClaveCancelada();
    _pendiente = null;
    emit(SosEnviado(alertaId: value.alertaId));
  }

  void _programarReintento(PendingSos pendiente, Emitter<SosState> emit) {
    if (_intentos >= _backoff.length) {
      // Se agotaron los reintentos automaticos. El pendiente se conserva: al
      // pulsar SOS de nuevo (o al reanudar la app) se reintenta con la misma
      // clave, sin crear otra alerta.
      emit(const SosError(
        'No se pudo conectar con la central. Reintenta o llama al serenazgo.',
      ));
      return;
    }

    final retardo = _backoff[_intentos];
    _intentos++;
    _pendiente = pendiente;
    emit(const SosConectandoCentral());
    _timer = Timer(retardo, () {
      if (isClosed) return;
      add(SosReintentar(pendiente));
    });
  }

  Future<PendingSos?> _leerPendiente() async {
    try {
      return await _store.readPending();
    } catch (_) {
      return null;
    }
  }

  /// true si habia un pendiente en disco pero [SosStore.readPending] lo
  /// descarto por expiracion (TTL). Se usa para avisar "No se pudo enviar".
  Future<bool> _huboPendienteExpirado() async {
    try {
      return await _store.hayPendienteExpirado();
    } catch (_) {
      return false;
    }
  }

  Future<void> _guardarPendiente(PendingSos pendiente) async {
    try {
      await _store.savePending(pendiente);
    } catch (_) {
      // Sin almacenamiento seguro disponible (p. ej. test): el SOS sigue.
    }
  }

  Future<void> _descartarPendiente() async {
    try {
      await _store.clearPending();
    } catch (_) {}
  }

  Future<void> _descartarClaveCancelada() async {
    try {
      await _store.clearClaveCancelada();
    } catch (_) {}
  }

  Future<void> _guardarSesion(String alertaId, String sessionToken) async {
    try {
      await _store.save(alertaId: alertaId, sessionToken: sessionToken);
    } catch (_) {}
  }

  Future<void> _descartarSesion() async {
    try {
      await _store.clear();
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}