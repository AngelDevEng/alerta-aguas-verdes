import 'dart:async';
import 'dart:math' show min;

import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/detalle_incidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/evidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/incidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/incidencia_mapa.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/tipo_incidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/repositories/incidencia_repository.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/usecases/incidencia_usecases.dart';
import 'package:alerta_aguas_verdes/features/incidencias/presentation/bloc/incidencias_bloc.dart';
import 'package:alerta_aguas_verdes/features/incidencias/presentation/bloc/incidencias_event.dart';
import 'package:alerta_aguas_verdes/features/incidencias/presentation/bloc/incidencias_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

Incidencia _inc({
  String id = 'inc-1',
  int tipoId = 1,
  String tipo = 'Robo',
  EstadoIncidencia estado = EstadoIncidencia.registrada,
}) =>
    Incidencia(
      id: id,
      codigo: 'INC-$id',
      tipo: tipo,
      tipoId: tipoId,
      estado: estado,
      prioridad: Prioridad.media,
      latitud: -12.05,
      longitud: -77.04,
      ocurridoEn: DateTime.utc(2026, 3, 1, 12),
      evidencias: 0,
    );

PaginaIncidencias _pagina(List<Incidencia> items, {int total = 1, int page = 1, int limit = 20}) =>
    PaginaIncidencias(items: items, total: total, page: page, limit: limit);

/// Doble de prueba que tambien implementa la derivacion de tipos.
///
/// [tiposDisponibles] va en el fake a proposito y no en un mock: la logica de
/// unir tipos entre paginas vive en el repositorio, y un mock que devuelve una
/// lista fija probaria que el bloc la copia, no que une lo que debe unir.
class FakeListaRepository implements IncidenciaRepository {
  /// Respuestas de `listar`, por orden de llamada; se repite la ultima al
  /// agotarse.
  final List<Result<PaginaIncidencias>> respuestas = [];

  /// Respuestas que se entregan a mano, en orden.
  final List<Completer<Result<PaginaIncidencias>>> cola = [];

  final List<FiltrosIncidencia> consultas = [];

  int llamadas = 0;

  @override
  Future<Result<PaginaIncidencias>> listar(FiltrosIncidencia filtros) {
    consultas.add(filtros);
    final porDefecto = respuestas.isEmpty
        ? const Ok(PaginaIncidencias.vacia())
        : respuestas[min(respuestas.length - 1, llamadas)];
    llamadas++;
    return cola.isEmpty ? Future.value(porDefecto) : cola.removeAt(0).future;
  }

  // Solo lo usa el mapa (`MapaBloc`), que este test no toca.
  @override
  Future<Result<List<IncidenciaMapa>>> geojson() =>
      throw UnimplementedError('geojson() no se usa en este test');

  @override
  List<TipoIncidenciaDisponible> tiposDisponibles(
    List<Incidencia> cargadas, {
    List<TipoIncidenciaDisponible> previos = const [],
  }) {
    // Misma regla que `IncidenciaRepository`: une lo nuevo con lo previo, y si
    // un id se repite gana el nombre que ya se tenia en pantalla para que el
    // chip y el desplegable no puedan divergir.
    final porId = <int, String>{
      for (final t in previos) t.id: t.nombre,
      for (final i in cargadas) i.tipoId: i.tipo,
    };
    return porId.entries
        .map((e) => TipoIncidenciaDisponible(id: e.key, nombre: e.value))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Future<Result<DetalleIncidencia>> obtenerDetalle(String id) async =>
      const Err(NotFoundFailure());

  @override
  Future<Result<String>> crear(NuevaIncidencia datos) async => const Ok('inc-1');

  @override
  Future<Result<Evidencia>> subirEvidencia(String id, EvidenciaAdjunta e) async =>
      const Ok(Evidencia(id: 'e-1', url: 'http://x/e-1'));

  @override
  Future<Result<DetalleIncidencia>> cambiarEstado(String id, EstadoIncidencia e) async =>
      const Err(NotFoundFailure());

  @override
  Future<Result<DetalleIncidencia>> asignarUnidad(String id, String unidadId) async =>
      const Err(NotFoundFailure());
}

IncidenciasBloc _bloc(FakeListaRepository repo) =>
    IncidenciasBloc(ListarIncidenciasUseCase(repo), repo);

Future<void> _asentar() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeListaRepository repo;

  setUp(() => repo = FakeListaRepository());

  group('carga', () {
    blocTest<IncidenciasBloc, IncidenciasState>(
      'consulta la pagina 1 y deja la lista cargada',
      build: () => _bloc(repo..respuestas.add(Ok(_pagina([_inc()])))),
      act: (b) => b.add(const CargarIncidencias()),
      expect: () => [
        isA<IncidenciasCargando>().having((e) => e.previo, 'sin pagina previa', isNull),
        isA<IncidenciasListas>()
            .having((e) => e.pagina.items.length, 'items', 1)
            .having((e) => e.filtros.page, 'pagina', 1),
      ],
    );

    blocTest<IncidenciasBloc, IncidenciasState>(
      'un fallo deja la pagina previa en pantalla en vez de vaciarla',
      // Vaciar la lista por un 500 tira a la basura lo que el operador ya estaba
      // leyendo y todavia es valido.
      build: () {
        repo.respuestas.addAll([
          Ok(_pagina([_inc()])),
          const Err(ServerFailure(503, 'No disponible')),
        ]);
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const CargarIncidencias());
        await _asentar();
        b.add(const CargarIncidencias());
      },
      expect: () => [
        isA<IncidenciasCargando>().having((e) => e.previo, 'sin previo', isNull),
        isA<IncidenciasListas>(),
        isA<IncidenciasCargando>().having((e) => e.previo?.items.length, 'conserva la pagina', 1),
        isA<IncidenciasError>()
            .having((e) => e.mensaje, 'mensaje', contains('No disponible'))
            .having((e) => e.previo?.items.length, 'con la pagina a mano', 1),
      ],
    );

    blocTest<IncidenciasBloc, IncidenciasState>(
      'reusar filtros al recargar no devuelve al usuario a la pagina 1',
      build: () {
        repo.respuestas.addAll([
          Ok(_pagina([_inc()], total: 60, page: 1)),
          Ok(_pagina([_inc(id: 'inc-2')], total: 60, page: 2)),
          Ok(_pagina([_inc(id: 'inc-3')], total: 60, page: 2)),
        ]);
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const CargarIncidencias());
        await _asentar();
        b.add(const CambiarPagina(2));
        await _asentar();
        b.add(const CargarIncidencias());
      },
      verify: (b) {
        expect(repo.consultas.map((f) => f.page), [1, 2, 2]);
      },
    );

    blocTest<IncidenciasBloc, IncidenciasState>(
      'los tipos ya conocidos sobreviven a la recarga',
      // El desplegable de tipo se arma con lo ya cargado y no hay endpoint para
      // pedirlo: si se perdiera al entrar en carga, el filtro se abriria sin
      // opciones en pleno refresh.
      build: () {
        repo.respuestas.addAll([
          Ok(_pagina([_inc(tipoId: 1, tipo: 'Robo'), _inc(id: 'x', tipoId: 2, tipo: 'Residuos')])),
          const Err(NetworkFailure()),
        ]);
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const CargarIncidencias());
        await _asentar();
        b.add(const CargarIncidencias());
      },
      verify: (b) {
        expect(b.state.tipos.map((t) => t.id), [1, 2]);
        expect(b.state.nombreDeTipo(2), 'Residuos');
        expect(b.state.nombreDeTipo(99), isNull);
        expect(b.state.nombreDeTipo(null), isNull);
      },
    );
  });

  group('descarte de respuestas vieja', () {
    test('una respuesta vieja no pisa a la vigente', () async {
      final vieja = Completer<Result<PaginaIncidencias>>();
      final nueva = Completer<Result<PaginaIncidencias>>();
      repo.cola.addAll([vieja, nueva]);
      final bloc = _bloc(repo);

      final vistos = expectLater(
        bloc.stream,
        emitsInOrder([
          // La segunda consulta vuelve a emitir `Cargando` porque en la primera
          // carga no hay pagina previa todavia. Lo que importa es que solo haya
          // un `Listas`: el de la respuesta vigente.
          isA<IncidenciasCargando>(),
          isA<IncidenciasListas>(),
        ]),
      );

      bloc.add(const CargarIncidencias());
      await _asentar();
      bloc.add(const CargarIncidencias());
      await _asentar();

      nueva.complete(Ok(_pagina([_inc(id: 'nueva')])));
      await _asentar();
      vieja.complete(Ok(_pagina([_inc(id: 'vieja')])));

      await vistos;
      await bloc.close();

      expect((bloc.state as IncidenciasListas).pagina.items.single.id, 'nueva');
    });

    test('una respuesta que llega con el bloc cerrado se descarta', () async {
      final pendiente = Completer<Result<PaginaIncidencias>>();
      repo.cola.add(pendiente);
      final bloc = _bloc(repo);

      bloc.add(const CargarIncidencias());
      await _asentar();
      await bloc.close();

      pendiente.complete(Ok(_pagina([_inc()])));
      await _asentar();

      expect(bloc.state, isA<IncidenciasCargando>());
    });
  });

  group('filtros', () {
    blocTest<IncidenciasBloc, IncidenciasState>(
      'aplicar un filtro vuelve a la pagina 1',
      // Filtrar en la pagina 3 puede dejar la pantalla vacia y parece un fallo.
      build: () {
        repo.respuestas.add(Ok(_pagina([_inc()], total: 60)));
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const CargarIncidencias());
        await _asentar();
        b.add(const CambiarPagina(2));
        await _asentar();
        b.add(const AplicarFiltros(estado: EstadoIncidencia.despachada));
      },
      verify: (b) {
        expect(b.state.filtros.page, 1);
        expect(b.state.filtros.estado, EstadoIncidencia.despachada);
      },
    );

    blocTest<IncidenciasBloc, IncidenciasState>(
      'limpiar un filtro deja el valor anterior en null',
      // `copyWith` con `limpiar*` es lo que evita el filtro fantasma: sin el,
      // deseleccionar "estado" en la hoja noeria nada y el chip diria que sigue
      // filtrando.
      build: () => _bloc(repo),
      act: (b) async {
        b.add(const AplicarFiltros(estado: EstadoIncidencia.despachada, tipoId: 3));
        await _asentar();
        b.add(const AplicarFiltros(
          limpiarEstado: true,
          limpiarTipo: true,
        ));
      },
      verify: (b) {
        expect(b.state.filtros.estado, isNull);
        expect(b.state.filtros.tipoId, isNull);
      },
    );

    blocTest<IncidenciasBloc, IncidenciasState>(
      'limpiar todo vuelve a los filtros de factory',
      build: () {
        repo.respuestas.add(Ok(_pagina([_inc()])));
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const AplicarFiltros(estado: EstadoIncidencia.despachada));
        await _asentar();
        b.add(const LimpiarFiltros());
      },
      verify: (b) => expect(b.state.filtros, const FiltrosIncidencia()),
    );
  });

  group('paginacion', () {
    blocTest<IncidenciasBloc, IncidenciasState>(
      'avanza y retrocede conservando los filtros',
      build: () {
        repo.respuestas.add(Ok(_pagina([_inc()], total: 60)));
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const AplicarFiltros(estado: EstadoIncidencia.despachada));
        await _asentar();
        b.add(const CambiarPagina(2));
        await _asentar();
        b.add(const CambiarPagina(1));
      },
      verify: (b) => expect(
        repo.consultas.map((f) => (f.page, f.estado)),
        [
          (1, EstadoIncidencia.despachada),
          (2, EstadoIncidencia.despachada),
          (1, EstadoIncidencia.despachada),
        ],
      ),
    );

    blocTest<IncidenciasBloc, IncidenciasState>(
      'ignora una pagina fuera de rango',
      // Con 60 resultados y limite 20 hay 3 paginas: pedir la 9 es un bug de la
      // pantalla, no una consulta valida.
      build: () {
        repo.respuestas.add(Ok(_pagina([_inc()], total: 60)));
        return _bloc(repo);
      },
      act: (b) async {
        b.add(const CargarIncidencias());
        await _asentar();
        b.add(const CambiarPagina(9));
        await _asentar();
        b.add(const CambiarPagina(0));
        await _asentar();
        b.add(const CambiarPagina(1));
      },
      verify: (_) => expect(repo.llamadas, 1, reason: 'solo la carga inicial'),
    );

    blocTest<IncidenciasBloc, IncidenciasState>(
      'no pagina sin resultados cargados',
      // Sin total no hay cuantas paginas hay; inventar un limite seria pedir
      // paginas vacias.
      build: () => _bloc(repo),
      act: (b) => b.add(const CambiarPagina(2)),
      expect: () => <IncidenciasState>[],
    );
  });
}
