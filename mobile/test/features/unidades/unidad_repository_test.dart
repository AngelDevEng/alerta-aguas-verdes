import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/features/unidades/data/datasources/unidad_remote_datasource.dart';
import 'package:alerta_aguas_verdes/features/unidades/data/repositories/unidad_repository_impl.dart';
import 'package:alerta_aguas_verdes/features/unidades/domain/entities/unidad.dart';
import 'package:flutter_test/flutter_test.dart';

Unidad _u(String id, EstadoUnidad estado) => Unidad(
      id: id,
      codigo: 'U-$id',
      tipo: TipoUnidad.patrulla,
      estado: estado,
    );

/// Doble del datasource: sin red, solo para ver como el repositorio filtra.
///
/// Lo que se prueba aca es la regla "despachable = DISPONIBLE", que es lo unico
/// que el repositorio agrega sobre el datasource. La regla no vive en la
/// pantalla a proposito: si viviera ahi, cada pantalla la tendria que recordar,
/// y una que se olvide ofrece al operador unidades que el backend rechaza con
/// 400.
class _RemoteFalso implements UnidadRemoteDataSource {
  Result<List<Unidad>> respuesta = const Ok([]);

  @override
  Future<Result<List<Unidad>>> listar() async => respuesta;

  @override
  Future<Result<List<UnidadCercana>>> cercanas({
    required double longitud,
    required double latitud,
    double radioM = 3000,
  }) async =>
      const Ok([]);
}

void main() {
  test('listarDespachables deja solo las DISPONIBLES', () async {
    final remote = _RemoteFalso()
      ..respuesta = Ok([
        _u('1', EstadoUnidad.disponible),
        _u('2', EstadoUnidad.ocupada),
        _u('3', EstadoUnidad.fueraDeServicio),
        _u('4', EstadoUnidad.unknown),
        _u('5', EstadoUnidad.disponible),
      ]);
    final repo = UnidadRepositoryImpl(remote);

    final r = await repo.listarDespachables();

    expect(r, isA<Ok<List<Unidad>>>());
    final lista = (r as Ok<List<Unidad>>).value;
    expect(lista.map((u) => u.id), ['1', '5']);
    // `unknown` es lo que devuelve `fromWire` cuando el backend agrega un
    // estado que la app no conoce todavia; dejarlo fuera del despacho es lo
    // seguro: no sabemos si el servidor lo aceptaria.
    expect(lista.every((u) => u.estado.asignable), isTrue);
  });

  test('una falla del datasource se propaga sin perder el mensaje', () async {
    final remote = _RemoteFalso()..respuesta = const Err(NetworkFailure());
    final repo = UnidadRepositoryImpl(remote);

    final r = await repo.listarDespachables();

    expect(r, isA<Err<List<Unidad>>>());
    expect((r as Err<List<Unidad>>).failure, isA<NetworkFailure>());
  });

  test('el filtro es estructural: una lista vacia sigue siendo un exito', () async {
    // Sin unidades disponibles no hay error: es el estado habitual a media
    // noche. Pintar "error" ahi llevaria al operador a reintentar sin parar.
    final remote = _RemoteFalso()..respuesta = const Ok([]);
    final repo = UnidadRepositoryImpl(remote);

    final r = await repo.listarDespachables();

    expect(r, isA<Ok<List<Unidad>>>());
    expect((r as Ok<List<Unidad>>).value, isEmpty);
  });

  test('distanciaTexto escala de metros a kilometros en el borde de 1000', () {
    expect(
      const UnidadCercana(id: '1', codigo: 'U-1', tipo: TipoUnidad.pie, distanciaM: 850)
          .distanciaTexto,
      '850 m',
    );
    expect(
      const UnidadCercana(id: '2', codigo: 'U-2', tipo: TipoUnidad.pie, distanciaM: 1500)
          .distanciaTexto,
      '1.5 km',
    );
  });

  test('etiquetaOperador arma codigo + placa, o solo codigo si no hay placa', () {
    // La unidad no tiene `nombre`: este texto es lo unico que la identifica en
    // la operacion. Probarlo evita que alguien "mejore" el formato y rompa la
    // regla de mostrar siempre ambos datos cuando existen.
    expect(
      const Unidad(
        id: '1',
        codigo: 'U-12',
        tipo: TipoUnidad.patrulla,
        estado: EstadoUnidad.disponible,
        placa: ' ABC-123 ',
      ).etiquetaOperador,
      'U-12 · ABC-123',
    );
    expect(
      const Unidad(
        id: '2',
        codigo: 'U-7',
        tipo: TipoUnidad.pie,
        estado: EstadoUnidad.disponible,
      ).etiquetaOperador,
      'U-7',
    );
  });
}
