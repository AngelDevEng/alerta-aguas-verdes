import 'dart:async';
import 'dart:math' show min;

import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/detalle_incidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/evidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/incidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/tipo_incidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/repositories/incidencia_repository.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/usecases/incidencia_usecases.dart';
import 'package:alerta_aguas_verdes/features/incidencias/presentation/bloc/incidencia_detalle_bloc.dart';
import 'package:alerta_aguas_verdes/features/incidencias/presentation/bloc/incidencia_detalle_event.dart';
import 'package:alerta_aguas_verdes/features/incidencias/presentation/bloc/incidencia_detalle_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

DetalleIncidencia _detalle({
  EstadoIncidencia estado = EstadoIncidencia.registrada,
  String? unidadAsignadaId,
}) =>
    DetalleIncidencia(
      incidencia: Incidencia(
        id: 'inc-1',
        codigo: 'INC-0001',
        tipo: 'Robo',
        tipoId: 1,
        estado: estado,
        prioridad: Prioridad.alta,
        latitud: -12.05,
        longitud: -77.04,
        ocurridoEn: DateTime.utc(2026, 3, 1, 12),
        evidencias: 0,
        unidadAsignadaId: unidadAsignadaId,
      ),
      historial: const [],
      evidencias: const [],
    );

/// Estado de la incidencia en pantalla.
///
/// Se extrae con [DetalleVisible.detalle] y no leyendo solo [DetalleCargado] para
/// que el matcher sirva igual para un estado cargado y para el "anterior" de un
/// fallo de accion: es justamente la garantia que importa en esos casos.
Matcher _estadoEnPantalla(EstadoIncidencia esperado) => predicate<IncidenciaDetalleState>(
      (e) => e.detalle?.incidencia.estado == esperado,
      'la pantalla muestra $esperado',
    );

/// Doble de prueba con control sobre la respuesta de cada llamada.
///
/// Las colas por metodo son lo que permite probar el descarte de respuestas
/// vieja: hace falta que la primera consulta siga abierta cuando llega la
/// segunda, y eso no se puede simular con un `async` que ya termino.
class FakeDetalleRepository implements IncidenciaRepository {
  /// Respuesta de `obtenerDetalle` cuando no hay nada en [cargas] ni en la cola.
  Result<DetalleIncidencia> detalle = Ok(_detalle());

  /// Respuestas de `obtenerDetalle` por orden de llamada.
  ///
  /// Si se agota la lista se repite la ultima: alcanza para distinguir "primera
  /// carga" de "recarga", que es lo que necesita el test del spinner.
  final List<Result<DetalleIncidencia>> cargas = [];

  Result<DetalleIncidencia> resultadoEstado = Ok(_detalle());
  Result<DetalleIncidencia> resultadoAsignar =
      Ok(_detalle(estado: EstadoIncidencia.despachada, unidadAsignadaId: 'u-1'));

  /// Respuestas que se entregan a mano, en orden, por llamada.
  final List<Completer<Result<DetalleIncidencia>>> colaCarga = [];
  final List<Completer<Result<DetalleIncidencia>>> colaEstado = [];
  final List<Completer<Result<DetalleIncidencia>>> colaAsignar = [];

  int llamadasEstado = 0;
  int llamadasAsignar = 0;
  String? ultimaUnidad;

  Future<Result<DetalleIncidencia>> _responder(
    List<Completer<Result<DetalleIncidencia>>> cola,
    Result<DetalleIncidencia> porDefecto,
  ) =>
      cola.isEmpty ? Future.value(porDefecto) : cola.removeAt(0).future;

  @override
  Future<Result<DetalleIncidencia>> obtenerDetalle(String id) {
    final porDefecto = cargas.isEmpty
        ? detalle
        : cargas[min(cargas.length - 1, _cargasHechas)];
    _cargasHechas++;
    return _responder(colaCarga, porDefecto);
  }

  int _cargasHechas = 0;

  @override
  Future<Result<DetalleIncidencia>> cambiarEstado(
    String id,
    EstadoIncidencia estado,
  ) {
    llamadasEstado++;
    return _responder(colaEstado, resultadoEstado);
  }

  @override
  Future<Result<DetalleIncidencia>> asignarUnidad(String id, String unidadId) {
    llamadasAsignar++;
    ultimaUnidad = unidadId;
    return _responder(colaAsignar, resultadoAsignar);
  }

  @override
  Future<Result<PaginaIncidencias>> listar(FiltrosIncidencia f) async =>
      const Ok(PaginaIncidencias.vacia());

  @override
  Future<Result<String>> crear(NuevaIncidencia datos) async => const Ok('inc-1');

  @override
  Future<Result<Evidencia>> subirEvidencia(String id, EvidenciaAdjunta e) async =>
      const Ok(Evidencia(id: 'e-1', url: 'http://x/e-1'));

  @override
  List<TipoIncidenciaDisponible> tiposDisponibles(
    List<Incidencia> cargadas, {
    List<TipoIncidenciaDisponible> previos = const [],
  }) =>
      const [];
}

IncidenciaDetalleBloc _bloc(FakeDetalleRepository repo) => IncidenciaDetalleBloc(
      ObtenerDetalleIncidenciaUseCase(repo),
      CambiarEstadoIncidenciaUseCase(repo),
      AsignarUnidadUseCase(repo),
      'inc-1',
    );

/// Deja que el bloc termine de procesar lo que ya estaba encolado.
Future<void> _asentar() => Future<void>.delayed(Duration.zero);

void main() {
  group('carga inicial', () {
    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'pide el detalle y lo muestra cargado',
      build: () => _bloc(FakeDetalleRepository()),
      act: (b) => b.add(const DetalleSolicitado()),
      expect: () => [
        isA<DetalleCargando>(),
        isA<DetalleCargado>()
            .having((e) => e.accionEnCurso, 'sin accion en curso', isFalse)
            .having((e) => e.detalle.incidencia.id, 'id', 'inc-1'),
      ],
    );

    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'un fallo sin detalle previo deja la pantalla en error total',
      build: () => _bloc(FakeDetalleRepository()..detalle = const Err(NotFoundFailure())),
      act: (b) => b.add(const DetalleSolicitado()),
      expect: () => [
        isA<DetalleCargando>(),
        isA<DetalleError>().having((e) => e.failure, 'falla', isA<NotFoundFailure>()),
      ],
    );

    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'un reload con detalle cargado no vuelve a mostrar el spinner',
      // El parpadeo no es cosmetico: si la pantalla se tapa mientras se
      // recarga, el operador pierde de vista el caso que esta leyendo. La
      // secuencia esperada es exacta, asi que un `DetalleCargando` de mas rompe
      // el test.
      build: () => _bloc(FakeDetalleRepository()
        ..cargas.addAll([
          Ok(_detalle()),
          Ok(_detalle(estado: EstadoIncidencia.enAtencion)),
        ])),
      act: (b) async {
        b.add(const DetalleSolicitado());
        await _asentar();
        b.add(const DetalleSolicitado());
      },
      expect: () => [
        isA<DetalleCargando>(),
        _estadoEnPantalla(EstadoIncidencia.registrada),
        _estadoEnPantalla(EstadoIncidencia.enAtencion),
      ],
    );
  });

  group('descarte de respuestas vieja', () {
    test('la primera carga no pisa el resultado de la segunda', () async {
      // Sin el guardia, la respuesta vieja que llega ultima deja el detalle con
      // el estado previo al refresh: el sintoma clasico de "refresco y me vuelve
      // el dato viejo".
      final primera = Completer<Result<DetalleIncidencia>>();
      final segunda = Completer<Result<DetalleIncidencia>>();
      final repo = FakeDetalleRepository()..colaCarga.addAll([primera, segunda]);
      final bloc = _bloc(repo);

      final vistos = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<DetalleCargando>(),
          _estadoEnPantalla(EstadoIncidencia.atendida),
        ]),
      );

      bloc.add(const DetalleSolicitado());
      await _asentar();
      bloc.add(const DetalleSolicitado());
      await _asentar();

      // La segunda, que es la que manda, responde primero.
      segunda.complete(Ok(_detalle(estado: EstadoIncidencia.atendida)));
      await _asentar();
      // La primera responde tarde con el dato viejo: no debe emitir nada.
      primera.complete(Ok(_detalle(estado: EstadoIncidencia.registrada)));

      await vistos;
      await bloc.close();

      expect(bloc.state.detalle!.incidencia.estado, EstadoIncidencia.atendida);
    });

    test('una respuesta que llega con el bloc cerrado se descarta', () async {
      // El caso que justifica el `isClosed` del guardia: el usuario sale de la
      // pantalla mientras el `GET` sigue en vuelo. Sin el chequeo, el bloc emite
      // sobre un `StreamController` ya cerrado y Flutter revienta con un
      // assertion.
      final pendiente = Completer<Result<DetalleIncidencia>>();
      final repo = FakeDetalleRepository()..colaCarga.add(pendiente);
      final bloc = _bloc(repo);

      bloc.add(const DetalleSolicitado());
      await _asentar();
      await bloc.close();

      pendiente.complete(Ok(_detalle()));
      await _asentar();

      // Si el guardia fallara, el `emit` habria lanzado y el test se caeria.
      expect(bloc.state, isA<DetalleCargando>());
    });
  });

  group('cambio de estado', () {
    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'marca la accion en curso y aplica el detalle que devuelve el backend',
      build: () => _bloc(FakeDetalleRepository()
        ..resultadoEstado = Ok(_detalle(estado: EstadoIncidencia.enAtencion))),
      act: (b) async {
        b.add(const DetalleSolicitado());
        await _asentar();
        b.add(const DetalleEstadoCambiado(EstadoIncidencia.enAtencion));
      },
      // Secuencia completa, sin `skip`: asi el test tambien dice que el cambio de
      // estado no vuelve a tapar la pantalla con un spinner.
      expect: () => [
        isA<DetalleCargando>(),
        _estadoEnPantalla(EstadoIncidencia.registrada),
        isA<DetalleCargado>().having((e) => e.accionEnCurso, 'en curso', isTrue),
        isA<DetalleCargado>()
            .having((e) => e.accionEnCurso, 'fin', isFalse)
            .having((e) => e.detalle.incidencia.estado, 'estado aplicado', EstadoIncidencia.enAtencion),
      ],
    );

    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'no reenvia un estado que ya es el actual',
      // El backend solo valida `@IsIn`, asi que aceptaria el reenvio y
      // agregaria una fila de historial identica: la duplicacion seria real.
      build: () {
        repo = FakeDetalleRepository();
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const DetalleSolicitado());
        await _asentar();
        b.add(const DetalleEstadoCambiado(EstadoIncidencia.registrada));
      },
      expect: () => [isA<DetalleCargando>(), isA<DetalleCargado>()],
      verify: (_) => expect(
        repo.llamadasEstado,
        0,
        reason: 'no debe tocar la red para un cambio que no cambia nada',
      ),
    );

    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'sin detalle cargado ignora el evento',
      // La pantalla nunca despacha sin detalle, pero el bloc no depende de eso:
      // si el evento llegara, no rompe.
      build: () => _bloc(FakeDetalleRepository()),
      act: (b) => b.add(const DetalleEstadoCambiado(EstadoIncidencia.atendida)),
      expect: () => <IncidenciaDetalleState>[],
    );

    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'un segundo cambio durante uno en vuelo se ignora',
      // Doble pulsacion: el backend no valida transiciones, asi que la segunda
      // entraria y generaria una fila de historial mas para un solo gesto.
      build: () => _bloc(FakeDetalleRepository()
        ..colaEstado.add(Completer<Result<DetalleIncidencia>>())),
      act: (b) async {
        b.add(const DetalleSolicitado());
        await _asentar();
        b.add(const DetalleEstadoCambiado(EstadoIncidencia.enAtencion));
        await _asentar();
        b.add(const DetalleEstadoCambiado(EstadoIncidencia.atendida));
      },
      // Secuencia completa: el `GET` inicial, el estado cargado y el toque. La
      // cuarta pulsacion no agrega nada, asi que no hay un cuarto estado.
      expect: () => [
        isA<DetalleCargando>(),
        _estadoEnPantalla(EstadoIncidencia.registrada),
        isA<DetalleCargado>().having((e) => e.accionEnCurso, 'en curso', isTrue),
      ],
    );

    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'un fallo conserva el detalle y no reabre la hoja de unidades',
      build: () => _bloc(FakeDetalleRepository()..resultadoEstado = const Err(ForbiddenFailure())),
      act: (b) async {
        b.add(const DetalleSolicitado());
        await _asentar();
        b.add(const DetalleEstadoCambiado(EstadoIncidencia.atendida));
      },
      expect: () => [
        isA<DetalleCargando>(),
        _estadoEnPantalla(EstadoIncidencia.registrada),
        isA<DetalleCargado>().having((e) => e.accionEnCurso, 'en curso', isTrue),
        isA<DetalleAccionFallida>()
            .having((e) => e.failure, 'falla', isA<ForbiddenFailure>())
            .having((e) => e.mostrarBorrador, 'sin hoja', isFalse)
            .having(
              (e) => e.anterior.detalle.incidencia.estado,
              'detalle intacto',
              EstadoIncidencia.registrada,
            ),
      ],
    );
  });

  group('despacho de unidad', () {
    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'envia la unidad elegida y aplica el detalle devuelto',
      build: () {
        repo = FakeDetalleRepository();
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const DetalleSolicitado());
        await _asentar();
        b.add(const DetalleUnidadAsignada('u-7'));
      },
      expect: () => [
        isA<DetalleCargando>(),
        _estadoEnPantalla(EstadoIncidencia.registrada),
        isA<DetalleCargado>().having((e) => e.accionEnCurso, 'en curso', isTrue),
        isA<DetalleCargado>()
            .having((e) => e.accionEnCurso, 'fin', isFalse)
            .having((e) => e.detalle.incidencia.unidadAsignadaId, 'unidad asignada', 'u-1')
            .having(
              (e) => e.detalle.incidencia.estado,
              'el backend paso el caso a DESPACHADA',
              EstadoIncidencia.despachada,
            ),
      ],
      verify: (_) => expect(repo.ultimaUnidad, 'u-7'),
    );

    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'ignora un id vacio antes de tocar la red',
      // Viene del `Navigator.pop` de una hoja cerrada. Mandarlo igual seria un
      // 400 que el operador no puede evitar.
      build: () {
        repo = FakeDetalleRepository();
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const DetalleSolicitado());
        await _asentar();
        b.add(const DetalleUnidadAsignada('   '));
      },
      skip: 3,
      expect: () => <IncidenciaDetalleState>[],
      verify: (_) => expect(repo.llamadasAsignar, 0),
    );

    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'si la unidad ya no esta disponible, marca que hay que reabrir la hoja',
      // Es la falla mas probable del flujo: otra persona la despacho primero.
      build: () => _bloc(FakeDetalleRepository()
        ..resultadoAsignar = const Err(ValidationFailure('La unidad no esta DISPONIBLE'))),
      act: (b) async {
        b.add(const DetalleSolicitado());
        await _asentar();
        b.add(const DetalleUnidadAsignada('u-7'));
      },
      expect: () => [
        isA<DetalleCargando>(),
        _estadoEnPantalla(EstadoIncidencia.registrada),
        isA<DetalleCargado>().having((e) => e.accionEnCurso, 'en curso', isTrue),
        isA<DetalleAccionFallida>()
            .having((e) => e.mostrarBorrador, 'reabre hoja', isTrue)
            .having((e) => e.failure.message, 'mensaje', contains('DISPONIBLE')),
      ],
    );
  });

  group('descarte del aviso', () {
    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'vuelve al ultimo estado sano sin volver a consultar',
      // Cerrar un `SnackBar` no puede costar una peticion de red: el detalle que
      // se quiso cambiar nunca llego a cambiar, sigue siendo el de [anterior].
      build: () {
        repo = FakeDetalleRepository()..resultadoEstado = const Err(ServerFailure(500, 'boom'));
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const DetalleSolicitado());
        await _asentar();
        b.add(const DetalleEstadoCambiado(EstadoIncidencia.atendida));
        await _asentar();
        b.add(const DetalleAvisoDescartado());
      },
      skip: 4,
      expect: () => [isA<DetalleCargado>().having((e) => e.accionEnCurso, 'sano', isFalse)],
      verify: (b) {
        expect(b.state.detalle!.incidencia.estado, EstadoIncidencia.registrada);
        expect(repo.llamadasEstado, 1, reason: 'descartar el aviso no consulta de nuevo');
      },
    );

    blocTest<IncidenciaDetalleBloc, IncidenciaDetalleState>(
      'sin aviso abierto el descarte no hace nada',
      build: () => _bloc(FakeDetalleRepository()),
      act: (b) async {
        b.add(const DetalleSolicitado());
        await _asentar();
        b.add(const DetalleAvisoDescartado());
      },
      skip: 3,
      expect: () => <IncidenciaDetalleState>[],
    );
  });
}

/// Doble de prueba del test anterior, asignado en `build`.
///
/// `bloc_test` solo entrega el bloc ya construido, asi que la unica forma de
/// llegar al fake desde `verify` es guardarlo en una variable del ambito del
/// test. `build` corre antes que `verify`, asi que el orden esta garantizado.
late FakeDetalleRepository repo;
