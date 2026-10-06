import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/core/location/location_service.dart';
import 'package:alerta_aguas_verdes/features/alertas/domain/repositories/alerta_repository.dart';
import 'package:alerta_aguas_verdes/features/alertas/domain/usecases/alerta_usecases.dart';
import 'package:alerta_aguas_verdes/features/alertas/presentation/bloc/sos_bloc.dart';
import 'package:alerta_aguas_verdes/features/alertas/presentation/bloc/sos_event.dart';
import 'package:alerta_aguas_verdes/features/alertas/presentation/bloc/sos_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// GPS simulado: [falla] si no hay posicion, o la posicion dada.
///
/// [retardo] permite abrir la ventana en la que un segundo toque del usuario
/// entra al BLoC mientras el primero sigue en vuelo.
class _LocationFake implements LocationService {
  _LocationFake({
    this.posicion,
    this.falla,
    this.retardo = Duration.zero,
  });

  final PosicionActual? posicion;
  final Failure? falla;
  final Duration retardo;

  @override
  Future<Result<PosicionActual>> posicionActual() async {
    if (retardo > Duration.zero) await Future.delayed(retardo);
    return falla != null ? Err(falla!) : Ok(posicion!);
  }
}

const _posicion = PosicionActual(
  latitud: -3.4825,
  longitud: -80.245,
  precisionMetros: 12,
);

/// Backend simulado: cuenta llamadas y captura lo que se envio.
class _AlertasFake implements AlertaRepository {
  _AlertasFake({this.falla});

  final Failure? falla;

  int llamadas = 0;
  double? latitudEnviada;
  double? longitudEnviada;
  double? precisionEnviada;

  @override
  Future<Result<String>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
  }) async {
    llamadas++;
    latitudEnviada = latitud;
    longitudEnviada = longitud;
    precisionEnviada = precisionM;
    if (falla != null) return Err(falla!);
    return const Ok('alerta-1');
  }
}

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

    test('propaga el id de la alerta creada', () async {
      final res = await EnviarSosUseCase(_AlertasFake())(
        latitud: -3.4825,
        longitud: -80.245,
        precisionM: 5,
      );

      expect(res.valueOrNull, 'alerta-1');
    });

    test('propaga la falla del backend tal cual', () async {
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

    SosBloc nuevoBloc({
      LocationService? location,
      Failure? backend,
    }) {
      repo = _AlertasFake(falla: backend);
      return SosBloc(
        location ??
            _LocationFake(posicion: _posicion),
        EnviarSosUseCase(repo),
      );
    }

    blocTest<SosBloc, SosState>(
      'GPS apagado: Enviando -> Error, sin tocar el backend',
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
        SosError('El GPS esta apagado. Activalo para ubicar la incidencia.'),
      ],
      verify: (_) => expect(repo.llamadas, 0),
    );

    blocTest<SosBloc, SosState>(
      'envio exitoso: Enviando -> Enviado, con la posicion del GPS',
      build: () => nuevoBloc(),
      act: (bloc) => bloc.add(const SosSolicitado()),
      expect: () => const [SosEnviando(), SosEnviado()],
      verify: (_) {
        expect(repo.llamadas, 1);
        expect(repo.latitudEnviada, -3.4825);
        expect(repo.longitudEnviada, -80.245);
        expect(repo.precisionEnviada, 12);
      },
    );

    blocTest<SosBloc, SosState>(
      'backend caido: Enviando -> Error con el mensaje del Failure',
      build: () => nuevoBloc(
        backend: const ServerFailure(
          500,
          'El servidor fallo (500). Intenta de nuevo.',
        ),
      ),
      act: (bloc) => bloc.add(const SosSolicitado()),
      expect: () => const [
        SosEnviando(),
        SosError('El servidor fallo (500). Intenta de nuevo.'),
      ],
      verify: (_) => expect(repo.llamadas, 1),
    );

    blocTest<SosBloc, SosState>(
      'dos toques rapidos durante el envio crean una sola alerta',
      build: () {
        repo = _AlertasFake();
        return SosBloc(
          _LocationFake(
            posicion: _posicion,
            retardo: const Duration(milliseconds: 50),
          ),
          EnviarSosUseCase(repo),
        );
      },
      act: (bloc) {
        bloc.add(const SosSolicitado());
        bloc.add(const SosSolicitado());
      },
      wait: const Duration(milliseconds: 200),
      expect: () => const [SosEnviando(), SosEnviado()],
      verify: (_) => expect(repo.llamadas, 1),
    );
  });
}
