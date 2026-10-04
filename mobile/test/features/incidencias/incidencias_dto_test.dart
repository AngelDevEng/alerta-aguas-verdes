import 'package:alerta_aguas_verdes/features/incidencias/data/models/incidencias_dto.dart';
import 'package:alerta_aguas_verdes/features/incidencias/domain/entities/incidencia.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fila tal como la devuelve `SELECT_BASE` en `incidencias.service.ts`.
Map<String, dynamic> fila({
  String estado = 'REGISTRADA',
  String prioridad = 'ALTA',
  Map<String, dynamic> extra = const {},
}) =>
    {
      'id': 'a1b2c3d4-0000-0000-0000-000000000001',
      'codigo': 'INC-000042',
      'tipo': 'Robo / hurto',
      'tipoId': 1,
      'descripcion': 'Sujeto se lleva un celular',
      'estado': estado,
      'prioridad': prioridad,
      'latitud': -12.0433,
      'longitud': -77.0282,
      'referencia': null,
      'unidadAsignadaId': null,
      'reportadoPor': '00000001',
      'reportadoPorNombre': 'Operador Demo',
      'ocurridoEn': '2026-09-30T14:05:00.000Z',
      'atendidoEn': null,
      'evidencias': 2,
      ...extra,
    };

void main() {
  group('IncidenciaDto.fromJson', () {
    test('mapea los alias camelCase que devuelve el SELECT', () {
      final dto = IncidenciaDto.fromJson(fila());

      expect(dto.codigo, 'INC-000042');
      expect(dto.tipo, 'Robo / hurto');
      expect(dto.tipoId, 1);
      expect(dto.latitud, -12.0433);
      expect(dto.longitud, -77.0282);
      expect(dto.evidencias, 2);
      expect(dto.reportadoPorNombre, 'Operador Demo');
      expect(dto.atendidoEn, isNull);
    });

    test('convierte a entidad con los enums resueltos', () {
      final entidad = IncidenciaDto.fromJson(fila()).toEntity();

      expect(entidad.estado, EstadoIncidencia.registrada);
      expect(entidad.prioridad, Prioridad.alta);
      expect(entidad.ocurridoEn.toUtc(), DateTime.utc(2026, 9, 30, 14, 5));
      expect(entidad.estaCerrada, isFalse);
    });

    test('acepta numeros que llegan como string', () {
      // node-postgres devuelve BIGINT como string en algunos drivers; el parseo
      // no debe tirar ni devolver 0 en silencio.
      final dto = IncidenciaDto.fromJson(
        fila(extra: {'tipoId': '4', 'evidencias': '7', 'latitud': '-12.5'}),
      );

      expect(dto.tipoId, 4);
      expect(dto.evidencias, 7);
      expect(dto.latitud, -12.5);
    });

    test('un estado o prioridad desconocidos no rompen el parseo', () {
      final entidad =
          IncidenciaDto.fromJson(fila(estado: 'ARCHIVADA', prioridad: 'URGENTE'))
              .toEntity();

      expect(entidad.estado, EstadoIncidencia.unknown);
      expect(entidad.prioridad, Prioridad.unknown);
    });

    test('no falla si faltan campos opcionales', () {
      final dto = IncidenciaDto.fromJson({'id': 'x'});

      expect(dto.codigo, '');
      expect(dto.tipo, '');
      expect(dto.tipoId, 0);
      expect(dto.evidencias, 0);
      expect(dto.descripcion, isNull);
      expect(dto.referencia, isNull);
      // Sin `ocurridoEn` hay que devolver una fecha utilizable, no un null que
      // reviente el formateo de la tarjeta.
      expect(dto.ocurridoEn.millisecondsSinceEpoch, 0);
    });

    test('una cadena vacia se normaliza a null, no a ""', () {
      final dto = IncidenciaDto.fromJson(fila(extra: {'referencia': ''}));

      expect(dto.referencia, isNull);
    });
  });

  group('PaginaIncidenciasDto.fromJson', () {
    test('lee la envoltura data + meta', () {
      final pagina = PaginaIncidenciasDto.fromJson({
        'data': [fila(), fila(extra: {'id': 'otra'})],
        'meta': {'total': 37, 'page': 2, 'limit': 20},
      }).toEntity();

      expect(pagina.items, hasLength(2));
      expect(pagina.total, 37);
      expect(pagina.page, 2);
      expect(pagina.limit, 20);
      expect(pagina.totalPaginas, 2);
      expect(pagina.hayAnterior, isTrue);
      expect(pagina.haySiguiente, isFalse);
    });

    test('trata data o meta ausentes como lista vacia', () {
      final pagina = PaginaIncidenciasDto.fromJson({}).toEntity();

      expect(pagina.items, isEmpty);
      expect(pagina.total, 0);
      expect(pagina.totalPaginas, 1);
      expect(pagina.haySiguiente, isFalse);
    });

    test('descarta filas que no son mapas en vez de fallar', () {
      final pagina = PaginaIncidenciasDto.fromJson({
        'data': [fila(), 'basura', null],
        'meta': {'total': 1},
      }).toEntity();

      expect(pagina.items, hasLength(1));
    });
  });

  group('FiltrosIncidencia.toQuery', () {
    test('omite lo no informado y siempre manda page y limit', () {
      final query = const FiltrosIncidencia().toQuery();

      expect(query.containsKey('estado'), isFalse);
      expect(query.containsKey('tipoId'), isFalse);
      expect(query.containsKey('desde'), isFalse);
      expect(query['page'], 1);
      expect(query['limit'], 20);
    });

    test('manda las fechas en ISO-8601 UTC porque el DTO valida con IsDateString', () {
      final local = DateTime(2026, 9, 30, 14, 5);
      final query = FiltrosIncidencia(desde: local, hasta: local).toQuery();

      expect(query['desde'], local.toUtc().toIso8601String());
      expect(query['hasta'], local.toUtc().toIso8601String());
    });

    test('no manda el wire de unknown porque el backend lo rechazaria', () {
      final query = const FiltrosIncidencia(estado: EstadoIncidencia.unknown)
          .toQuery();

      expect(query.containsKey('estado'), isFalse);
    });

    test('los flags de limpieza mandan sobre el valor', () {
      final base = const FiltrosIncidencia(
        estado: EstadoIncidencia.atendida,
        tipoId: 3,
      );
      final limpio = base.copyWith(limpiarEstado: true, limpiarTipo: true);

      expect(limpio.estado, isNull);
      expect(limpio.tipoId, isNull);
    });

    test('cambiar un filtro reinicia la paginacion a 1', () {
      const base = FiltrosIncidencia(
        estado: EstadoIncidencia.registrada,
        page: 5,
      );
      final filtrado = base.copyWith(estado: EstadoIncidencia.despachada);

      expect(filtrado.page, 1);
      expect(base.page, 5, reason: 'copyWith no debe mutar el original');
    });

    test('conPagina conserva los filtros', () {
      const base = FiltrosIncidencia(
        estado: EstadoIncidencia.atendida,
        tipoId: 3,
        page: 1,
      );
      final paginado = base.conPagina(4);

      expect(paginado.page, 4);
      expect(paginado.estado, EstadoIncidencia.atendida);
      expect(paginado.tipoId, 3);
    });

    test('la igualdad compara todos los filtros', () {
      const a = FiltrosIncidencia(estado: EstadoIncidencia.registrada);
      const b = FiltrosIncidencia(estado: EstadoIncidencia.registrada);
      const c = FiltrosIncidencia(estado: EstadoIncidencia.atendida);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
