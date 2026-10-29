import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/detalle_incidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/evidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/incidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/incidencia_mapa.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/tipo_incidencia.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/repositories/incidencia_repository.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/usecases/incidencia_usecases.dart';
import 'package:alerta_aguas_verdes/features/incidencias/presentation/bloc/reportar_bloc.dart';
import 'package:alerta_aguas_verdes/features/incidencias/presentation/bloc/reportar_event.dart';
import 'package:alerta_aguas_verdes/features/incidencias/presentation/bloc/reportar_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble de prueba.
///
/// Lo interesante es [llamadasCrear] y [fotosFallidasPorIndice]: permiten
/// comprobar que un reintento NO vuelve a crear la incidencia, que es el error
/// que duplicaria registros en la base.
class FakeIncidenciaRepository implements IncidenciaRepository {
  FakeIncidenciaRepository({
    this.fallaAlta,
    this.fotosQueFallan = const {},
    this.idGenerado = 'inc-1',
  });

  final Failure? fallaAlta;

  /// Indices de foto (0-based) que el backend rechaza.
  final Set<int> fotosQueFallan;

  final String idGenerado;

  int llamadasCrear = 0;
  int llamadasSubir = 0;

  @override
  Future<Result<String>> crear(NuevaIncidencia datos) async {
    llamadasCrear++;
    if (fallaAlta != null) return Err<String>(fallaAlta!);
    return Ok<String>(idGenerado);
  }

  @override
  Future<Result<Evidencia>> subirEvidencia(
    String incidenciaId,
    EvidenciaAdjunta evidencia,
  ) async {
    final indice = llamadasSubir;
    llamadasSubir++;
    if (fotosQueFallan.contains(indice)) {
      return Err<Evidencia>(
        const NetworkFailure('403: solo SERENO, OPERADOR o ADMIN'),
      );
    }
    return Ok<Evidencia>(
      Evidencia(id: 'ev-$indice', url: 'https://cdn/$indice.jpg'),
    );
  }

  @override
  Future<Result<PaginaIncidencias>> listar(FiltrosIncidencia filtros) async =>
      const Ok(PaginaIncidencias.vacia());

  // Solo lo usa el mapa (`MapaBloc`), que este test no toca.
  @override
  Future<Result<List<IncidenciaMapa>>> geojson() =>
      throw UnimplementedError('geojson() no se usa en este test');

  // El reporte no consulta el detalle, asi que estos tres quedan sin usar. Faltan
  // igual porque `IncidenciaRepository` no admite implementaciones parciales.
  @override
  Future<Result<DetalleIncidencia>> obtenerDetalle(String id) async =>
      const Err(NotFoundFailure());

  @override
  Future<Result<DetalleIncidencia>> cambiarEstado(String id, EstadoIncidencia estado) async =>
      const Err(NotFoundFailure());

  @override
  Future<Result<DetalleIncidencia>> asignarUnidad(String id, String unidadId) async =>
      const Err(NotFoundFailure());

  @override
  List<TipoIncidenciaDisponible> tiposDisponibles(
    List<Incidencia> cargadas, {
    List<TipoIncidenciaDisponible> previos = const [],
  }) =>
      const [];
}

EvidenciaAdjunta foto(int i) =>
    EvidenciaAdjunta(ruta: '/tmp/foto$i.jpg', nombre: 'foto$i.jpg');

const _datos = NuevaIncidencia(
  tipoId: 1,
  latitud: -12.0433,
  longitud: -77.0282,
  descripcion: 'Sujeto robando',
);

void main() {
  group('alta', () {
    blocTest<ReportarBloc, ReportarState>(
      'sin fotos termina en exito limpio',
      build: () => ReportarBloc(
        ReportarIncidenciaUseCase(FakeIncidenciaRepository()),
        SubirEvidenciaUseCase(FakeIncidenciaRepository()),
      ),
      act: (bloc) => bloc.add(ReportarSolicitado(datos: _datos)),
      expect: () => [
        const ReportarEnviando(fase: FaseReporte.creando),
        isA<ReportarExito>()
            .having((e) => e.fotosSubidas, 'fotosSubidas', 0)
            .having((e) => e.fotosFallidas, 'fotosFallidas', 0)
            .having((e) => e.parcial, 'parcial', false),
      ],
    );

    blocTest<ReportarBloc, ReportarState>(
      'si el alta falla no intenta subir ninguna foto',
      build: () {
        // Mismo texto que arma `ApiClient.toFailure` para un 5xx.
        final repo = FakeIncidenciaRepository(
          fallaAlta: const ServerFailure(500, 'El servidor fallo (500). Intenta de nuevo.'),
        );
        return ReportarBloc(
          ReportarIncidenciaUseCase(repo),
          SubirEvidenciaUseCase(repo),
        );
      },
      act: (bloc) => bloc.add(ReportarSolicitado(
        datos: _datos,
        evidencias: [foto(0), foto(1)],
      )),
      expect: () => [
        const ReportarEnviando(fase: FaseReporte.creando),
        isA<ReportarError>()
            .having((e) => e.mensaje, 'mensaje', contains('(500)')),
      ],
    );

    blocTest<ReportarBloc, ReportarState>(
      'un tipoId invalido se rechaza sin tocar la red',
      build: () => ReportarBloc(
        ReportarIncidenciaUseCase(FakeIncidenciaRepository()),
        SubirEvidenciaUseCase(FakeIncidenciaRepository()),
      ),
      act: (bloc) => bloc.add(ReportarSolicitado(
        datos: NuevaIncidencia(tipoId: 0, latitud: -12, longitud: -77),
      )),
      expect: () => [isA<ReportarError>()],
    );
  });

  group('evidencias', () {
    blocTest<ReportarBloc, ReportarState>(
      'sube todas las fotos cuando ninguna falla',
      build: () {
        final repo = FakeIncidenciaRepository();
        return ReportarBloc(
          ReportarIncidenciaUseCase(repo),
          SubirEvidenciaUseCase(repo),
        );
      },
      act: (bloc) => bloc.add(ReportarSolicitado(
        datos: _datos,
        evidencias: [foto(0), foto(1)],
      )),
      expect: () => [
        const ReportarEnviando(fase: FaseReporte.creando),
        const ReportarEnviando(fase: FaseReporte.subiendo, progreso: 1 / 3),
        const ReportarEnviando(fase: FaseReporte.subiendo, progreso: 2 / 3),
        isA<ReportarExito>()
            .having((e) => e.fotosSubidas, 'fotosSubidas', 2)
            .having((e) => e.parcial, 'parcial', false),
      ],
    );

    // Es el caso de un CIUDADANO: puede reportar pero `POST .../evidencias`
    // exige SERENO|OPERADOR|ADMIN. El reporte SI quedo guardado, asi que el
    // resultado correcto es exito parcial, no error.
    blocTest<ReportarBloc, ReportarState>(
      'si una foto falla informa exito parcial y la deja pendiente',
      build: () {
        final repo = FakeIncidenciaRepository(fotosQueFallan: {1});
        return ReportarBloc(
          ReportarIncidenciaUseCase(repo),
          SubirEvidenciaUseCase(repo),
        );
      },
      act: (bloc) => bloc.add(ReportarSolicitado(
        datos: _datos,
        evidencias: [foto(0), foto(1), foto(2)],
      )),
      expect: () => [
        const ReportarEnviando(fase: FaseReporte.creando),
        const ReportarEnviando(fase: FaseReporte.subiendo, progreso: 0.25),
        const ReportarEnviando(fase: FaseReporte.subiendo, progreso: 0.5),
        const ReportarEnviando(fase: FaseReporte.subiendo, progreso: 0.75),
        isA<ReportarExito>()
            .having((e) => e.fotosSubidas, 'fotosSubidas', 2)
            .having((e) => e.fotosFallidas, 'fotosFallidas', 1)
            .having((e) => e.parcial, 'parcial', true)
            // La que se debe poder reintentar es la que fallo. Se compara por
            // ruta y no por el objeto: EvidenciaAdjunta no define `==`.
            .having(
              (e) => e.pendientes.map((p) => p.ruta).toList(),
              'pendientes',
              ['/tmp/foto1.jpg'],
            ),
      ],
    );
  });

  group('ReintentarEvidencias', () {
    test('no vuelve a crear la incidencia: solo sube las fotos pendientes', () async {
      final repo = FakeIncidenciaRepository(fotosQueFallan: {0});
      final bloc = ReportarBloc(
        ReportarIncidenciaUseCase(repo),
        SubirEvidenciaUseCase(repo),
      );
      addTearDown(bloc.close);

      bloc.add(ReportarSolicitado(datos: _datos, evidencias: [foto(0)]));
      await bloc.stream.firstWhere((s) => s is ReportarExito);

      expect(repo.llamadasCrear, 1);
      expect((bloc.state as ReportarExito).pendientes, hasLength(1));

      // El segundo intento tiene que funcionar: el fake falla siempre el
      // indice 0, asi que se espera que ahora se subiria la foto 0 de nuevo y
      // falle otra vez, pero sin crear una incidencia nueva.
      bloc.add(const ReintentarEvidencias());
      await bloc.stream.firstWhere(
        (s) => s is ReportarExito || s is ReportarError,
      );

      expect(
        repo.llamadasCrear,
        1,
        reason: 'un reintento no debe llamar de nuevo a POST /incidencias',
      );
      expect(repo.llamadasSubir, 2);
    });

    test('sin un exito previo no hace nada', () async {
      final repo = FakeIncidenciaRepository();
      final bloc = ReportarBloc(
        ReportarIncidenciaUseCase(repo),
        SubirEvidenciaUseCase(repo),
      );
      addTearDown(bloc.close);

      bloc.add(const ReintentarEvidencias());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<ReportarInicial>());
      expect(repo.llamadasSubir, 0);
    });
  });
}
