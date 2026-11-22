import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/core/location/location_service.dart';
import 'package:alerta_aguas_verdes/core/storage/sos_session_store.dart';
import 'package:alerta_aguas_verdes/features/alertas/domain/entities/alerta_sos.dart';
import 'package:alerta_aguas_verdes/features/alertas/domain/repositories/alerta_repository.dart';
import 'package:alerta_aguas_verdes/features/alertas/domain/usecases/alerta_usecases.dart';
import 'package:alerta_aguas_verdes/features/alertas/presentation/bloc/sos_bloc.dart';
import 'package:alerta_aguas_verdes/features/alertas/presentation/bloc/sos_event.dart';
import 'package:alerta_aguas_verdes/features/alertas/presentation/bloc/sos_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// GPS simulado: [falla] si no hay posicion, o la posicion dada.
class _LocationFake implements LocationService {
  _LocationFake({this.posicion, this.falla});

  final PosicionActual? posicion;
  final Failure? falla;

  @override
  Future<Result<PosicionActual>> posicionActual() async =>
      falla != null ? Err(falla!) : Ok(posicion!);
}

/// Almacen en memoria del SOS (pendiente + sesion).
class _StoreFake implements SosStore {
  PendingSos? pending;
  String? alertaId;
  String? token;
  bool expirado = false;

  @override
  Future<String> deviceId() async => 'device-1';

  @override
  Future<void> save({required String alertaId, required String sessionToken}) async {
    this.alertaId = alertaId;
    token = sessionToken;
  }

  @override
  Future<({String alertaId, String sessionToken})?> read() async =>
      (alertaId != null && token != null)
          ? (alertaId: alertaId!, sessionToken: token!)
          : null;

  @override
  Future<void> clear() async {
    alertaId = null;
    token = null;
  }

  @override
  Future<void> savePending(PendingSos value) async => pending = value;

  @override
  Future<PendingSos?> readPending() async {
    if (expirado) {
      pending = null;
      return null;
    }
    return pending;
  }

  @override
  Future<bool> hayPendienteExpirado() async => expirado;

  @override
  Future<void> clearPending() async => pending = null;
}

/// Backend simulado: cuenta llamadas y captura lo que se envio.
class _AlertasFake implements AlertaRepository {
  _AlertasFake({this.falla, this.retardo = Duration.zero});

  final Failure? falla;
  final Duration retardo;

  int llamadas = 0;
  double? latitudEnviada;
  double? longitudEnviada;
  double? precisionEnviada;
  bool? sinUbicacionEnviada;
  String? idempotencyKeyEnviada;

  @override
  Future<Result<AlertaSos>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
    bool sinUbicacion = false,
    String? idempotencyKey,
  }) async {
    llamadas++;
    latitudEnviada = latitud;
    longitudEnviada = longitud;
    precisionEnviada = precisionM;
    sinUbicacionEnviada = sinUbicacion;
    idempotencyKeyEnviada = idempotencyKey;
    if (retardo > Duration.zero) await Future.delayed(retardo);
    if (falla != null) return Err(falla!);
    return const Ok(AlertaSos(alertaId: 'alerta-1', sessionToken: 'token-1'));
  }

  @override
  Future<Result<Map<String, dynamic>>> cambiarEstado(String id, String estado) async =>
      Ok({'id': id, 'estado': estado});
}

const _posicion = PosicionActual(
  latitud: -3.4825,
  longitud: -80.245,
  precisionMetros: 12,
);

void main() {
  group('EnviarSosUseCase', () {
    test('rechaza latitud fuera de rango sin llamar al repositorio', () async {
      final repo = _AlertasFake();
      final res = await EnviarSosUseCase(repo)(
        latitud: 91,
        longitud: -80.245,
      );

      expect(res.isErr, isTrue);
      expect(res.fold((f) => f.message, (_) => ''), contains('ubicacion'));
      expect(repo.llamadas, 0, reason: 'no debe gastar peticion HTTP');
    });

    test('descarta la precision ilegible y no pierde el SOS', () async {
      final repo = _AlertasFake();
      final res = await EnviarSosUseCase(repo)(
        latitud: -3.4825,
        longitud: -80.245,
        precisionM: double.nan,
      );

      expect(res.isOk, isTrue);
      expect(repo.precisionEnviada, isNull);
    });

    test('sin ubicacion omite la validacion de rango', () async {
      final repo = _AlertasFake();
      final res = await EnviarSosUseCase(repo)(
        latitud: 0,
        longitud: 0,
        sinUbicacion: true,
      );

      expect(res.isOk, isTrue);
      expect(repo.sinUbicacionEnviada, isTrue);
    });

    test('propaga el id y el token de la alerta creada', () async {
      final res = await EnviarSosUseCase(_AlertasFake())(
        latitud: -3.4825,
        longitud: -80.245,
        precisionM: 5,
      );

      expect(res.isOk, isTrue);
      expect(res.valueOrNull?.alertaId, 'alerta-1');
      expect(res.valueOrNull?.sessionToken, 'token-1');
    });

    test('propaga el fallo del backend tal cual', () async {
      final res = await EnviarSosUseCase(
        _AlertasFake(falla: const ServerFailure(503, 'El servidor fallo (503).')),
      )(
        latitud: -3.4825,
        longitud: -80.245,
      );

      expect(res.isErr, isTrue);
      expect(res.fold((f) => f.runtimeType, (_) => null), ServerFailure);
    });
  });

  group('SosBloc', () {
    late _AlertasFake repo;
    late _StoreFake store;

    SosBloc nuevoBloc({
      LocationService? location,
      Failure? backend,
    }) {
      repo = _AlertasFake(falla: backend);
      store = _StoreFake();
      return SosBloc(
        location ?? _LocationFake(posicion: _posicion),
        EnviarSosUseCase(repo),
        store,
      );
    }

    blocTest<SosBloc, SosState>(
      'envio exitoso: Enviando -> Enviado, con la posicion del GPS y clave idempotente',
      build: () => nuevoBloc(),
      act: (bloc) => bloc.add(const SosSolicitado()),
      expect: () => const [
        SosEnviando(),
        SosEnviado(alertaId: 'alerta-1', sessionToken: 'token-1'),
      ],
      verify: (_) {
        expect(repo.llamadas, 1);
        expect(repo.latitudEnviada, -3.4825);
        expect(repo.longitudEnviada, -80.245);
        expect(repo.precisionEnviada, 12);
        expect(repo.sinUbicacionEnviada, isFalse);
        expect(repo.idempotencyKeyEnviada, isNotNull);
        expect(store.pending, isNull, reason: 'el pendiente se limpia al exito');
        expect(store.alertaId, 'alerta-1');
      },
    );

    blocTest<SosBloc, SosState>(
      'GPS apagado: envia IGUAL, sin ubicacion (perder el SOS es peor)',
      build: () => nuevoBloc(
        location: _LocationFake(
          falla: const LocalFailure(
            'El GPS esta apagado. Activalo para ubicar la incidencia.',
          ),
        ),
      ),
      act: (bloc) => bloc.add(const SosSolicitado()),
      expect: () => const [
        SosEnviando(),
        SosEnviado(alertaId: 'alerta-1', sessionToken: 'token-1'),
      ],
      verify: (_) {
        expect(repo.llamadas, 1);
        expect(repo.sinUbicacionEnviada, isTrue);
        expect(repo.latitudEnviada, 0);
        expect(repo.idempotencyKeyEnviada, isNotNull);
      },
    );

    blocTest<SosBloc, SosState>(
      'fallo reintentable (5xx): Enviando -> ConectandoCentral y conserva el pendiente',
      build: () => nuevoBloc(
        backend: const ServerFailure(503, 'El servidor fallo (503).'),
      ),
      act: (bloc) => bloc.add(const SosSolicitado()),
      wait: const Duration(milliseconds: 100),
      expect: () => const [
        SosEnviando(),
        SosConectandoCentral(),
      ],
      verify: (_) {
        expect(repo.llamadas, 1, reason: 'el reintento aun no disparo');
        expect(store.pending, isNotNull, reason: 'el pendiente se conserva');
      },
    );

    blocTest<SosBloc, SosState>(
      '429 no se reintenta: Enviando -> Error y limpia el pendiente',
      build: () => nuevoBloc(
        backend: const RateLimitedFailure('Demasiados intentos. Espera un momento.'),
      ),
      act: (bloc) => bloc.add(const SosSolicitado()),
      wait: const Duration(milliseconds: 3000),
      expect: () => const [
        SosEnviando(),
        SosError('Demasiados intentos. Espera un momento.'),
      ],
      verify: (_) {
        expect(repo.llamadas, 1, reason: 'no debe reintentar un 429');
        expect(store.pending, isNull, reason: 'el pendiente se limpia');
      },
    );

    blocTest<SosBloc, SosState>(
      'reanudar pendiente: reutiliza la MISMA clave y envia',
      build: () {
        repo = _AlertasFake();
        store = _StoreFake()
          ..pending = PendingSos(
            idempotencyKey: 'clave-pendiente',
            latitud: -3.4825,
            longitud: -80.245,
            precisionM: 10,
          );
        return SosBloc(
          _LocationFake(posicion: _posicion),
          EnviarSosUseCase(repo),
          store,
        );
      },
      act: (bloc) => bloc.add(const SosReanudarPendiente()),
      expect: () => const [
        SosEnviando(),
        SosEnviado(alertaId: 'alerta-1', sessionToken: 'token-1'),
      ],
      verify: (_) {
        expect(repo.llamadas, 1);
        expect(repo.idempotencyKeyEnviada, 'clave-pendiente');
        expect(repo.latitudEnviada, -3.4825);
      },
    );

    blocTest<SosBloc, SosState>(
      'dos toques rapidos durante el envio crean una sola alerta',
      build: () {
        repo = _AlertasFake(retardo: const Duration(milliseconds: 50));
        store = _StoreFake();
        return SosBloc(
          _LocationFake(posicion: _posicion),
          EnviarSosUseCase(repo),
          store,
        );
      },
      act: (bloc) {
        bloc.add(const SosSolicitado());
        bloc.add(const SosSolicitado());
      },
      wait: const Duration(milliseconds: 200),
      expect: () => const [
        SosEnviando(),
        SosEnviado(alertaId: 'alerta-1', sessionToken: 'token-1'),
      ],
      verify: (_) => expect(repo.llamadas, 1),
    );

    blocTest<SosBloc, SosState>(
      'TTL: un pendiente expirado no se reanuda y avisa "No se pudo enviar"',
      build: () {
        repo = _AlertasFake();
        store = _StoreFake()..expirado = true;
        return SosBloc(
          _LocationFake(posicion: _posicion),
          EnviarSosUseCase(repo),
          store,
        );
      },
      act: (bloc) => bloc.add(const SosReanudarPendiente()),
      expect: () => const [
        SosError('No se pudo enviar, llama ahora al serenazgo.'),
      ],
      verify: (_) => expect(repo.llamadas, 0, reason: 'no reintenta un pendiente expirado'),
    );

    blocTest<SosBloc, SosState>(
      'cancelar: detiene el reintento y pasa a Cancelado',
      build: () {
        repo = _AlertasFake(
          falla: const ServerFailure(503, 'El servidor fallo (503).'),
        );
        store = _StoreFake();
        return SosBloc(
          _LocationFake(posicion: _posicion),
          EnviarSosUseCase(repo),
          store,
        );
      },
      act: (bloc) async {
        bloc.add(const SosSolicitado());
        // Esperar a que entre en backoff (ConectandoCentral) antes de cancelar.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const SosCancelarEnvio());
      },
      wait: const Duration(milliseconds: 100),
      expect: () => const [
        SosEnviando(),
        SosConectandoCentral(),
        SosCancelado(),
      ],
      verify: (_) {
        // Un solo intento: el cancel detuvo el backoff antes del segundo.
        expect(repo.llamadas, 1);
        // El pendiente se conserva (ya hubo intento) para poder reintentar.
        expect(store.pending, isNotNull);
      },
    );
  });
}