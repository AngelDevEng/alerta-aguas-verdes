import 'package:equatable/equatable.dart';

import '../../../../core/parsing/lector_json.dart';
import '../../domain/entities/evidencia.dart';
import '../../domain/entities/incidencia.dart';
import '../../domain/entities/tipo_incidencia.dart';

/// DTO de `GET /incidencias`.
///
/// El backend responde `{ data: [...], meta: { total, page, limit } }` donde
/// cada fila viene de `SELECT_BASE` en `incidencias.service.ts`. Los alias
/// del SELECT ya estan en camelCase, asi que no hay TranslateBackend.
class IncidenciaDto extends Equatable {
  const IncidenciaDto({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.tipoId,
    required this.estado,
    required this.prioridad,
    required this.latitud,
    required this.longitud,
    required this.ocurridoEn,
    required this.evidencias,
    this.descripcion,
    this.referencia,
    this.unidadAsignadaId,
    this.reportadoPor,
    this.reportadoPorNombre,
    this.atendidoEn,
  });

  final String id;

  /// Codigo corto que se muestra al usuario (por ejemplo `INC-000123`).
  final String codigo;

  final String tipo;
  final int tipoId;
  final String estado;
  final String prioridad;
  final double latitud;
  final double longitud;
  final DateTime ocurridoEn;

  /// Cantidad de evidencias. El detalle llega en `GET /incidencias/:id`.
  final int evidencias;

  final String? descripcion;

  /// Referencia opcional del reporte (patente, numero de expediente...).
  final String? referencia;

  final String? unidadAsignadaId;
  final String? reportadoPor;
  final String? reportadoPorNombre;
  final DateTime? atendidoEn;

  factory IncidenciaDto.fromJson(Map<String, dynamic> json) => IncidenciaDto(
        id: aTexto(json['id']),
        codigo: aTexto(json['codigo']),
        tipo: aTextoOpcional(json['tipo']) ?? '',
        tipoId: aEntero(json['tipoId']),
        estado: aTextoOpcional(json['estado']) ?? '',
        prioridad: aTextoOpcional(json['prioridad']) ?? '',
        latitud: aDoble(json['latitud']),
        longitud: aDoble(json['longitud']),
        ocurridoEn: aFecha(json['ocurridoEn']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        evidencias: aEntero(json['evidencias']),
        descripcion: aTextoOpcional(json['descripcion']),
        referencia: aTextoOpcional(json['referencia']),
        unidadAsignadaId: aTextoOpcional(json['unidadAsignadaId']),
        reportadoPor: aTextoOpcional(json['reportadoPor']),
        reportadoPorNombre: aTextoOpcional(json['reportadoPorNombre']),
        atendidoEn: aFecha(json['atendidoEn']),
      );

  @override
  List<Object?> get props => [
        id,
        codigo,
        tipo,
        tipoId,
        estado,
        prioridad,
        latitud,
        longitud,
        ocurridoEn,
        evidencias,
        descripcion,
        referencia,
        unidadAsignadaId,
        reportadoPor,
        reportadoPorNombre,
        atendidoEn,
      ];
}

/// Envoltura de la respuesta paginada.
///
/// [fromJson] es tolerante a que `data` o `meta` falten: si el servidor responde
/// `null` se trata como lista vacia en vez de romper la pantalla.
class PaginaIncidenciasDto {
  const PaginaIncidenciasDto({required this.items, required this.meta});

  final List<IncidenciaDto> items;

  /// `total`, `page` y `limit` del bloque `meta`.
  final MetaDto meta;

  factory PaginaIncidenciasDto.fromJson(Map<String, dynamic> json) => PaginaIncidenciasDto(
        items: aListaDeMapas(json['data']).map(IncidenciaDto.fromJson).toList(),
        meta: json['meta'] is Map
            ? MetaDto.fromJson(Map<String, dynamic>.from(json['meta'] as Map))
            : const MetaDto(),
      );
}

class MetaDto extends Equatable {
  const MetaDto({this.total = 0, this.page = 1, this.limit = 20});

  final int total;
  final int page;
  final int limit;

  factory MetaDto.fromJson(Map<String, dynamic> json) => MetaDto(
        total: aEntero(json['total']),
        page: aEntero(json['page']),
        limit: aEntero(json['limit']),
      );

  @override
  List<Object?> get props => [total, page, limit];
}

/// Traduce [NuevaIncidencia] al body de `POST /incidencias`.
///
/// Vive en `data/` porque los nombres de campo y el formato de fecha son un
/// detalle del transporte. Si el backend cambia el contrato, se toca aca y no
/// el formulario.
///
/// Omitir `prioridad` es intencional: el `INSERT` hace
/// `COALESCE($3, (SELECT prioridad FROM tipos_incidencia WHERE id = $1))`, asi
/// que mandarla vacia haria que el servidor la ignore.
class NuevaIncidenciaRequest {
  const NuevaIncidenciaRequest(this.datos);

  final NuevaIncidencia datos;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tipoId': datos.tipoId,
        'latitud': datos.latitud,
        'longitud': datos.longitud,
        if (datos.descripcion != null && datos.descripcion!.trim().isNotEmpty)
          'descripcion': datos.descripcion!.trim(),
        if (datos.prioridad != null) 'prioridad': datos.prioridad!.wire,
        if (datos.referencia != null && datos.referencia!.trim().isNotEmpty)
          'referencia': datos.referencia!.trim(),
        if (datos.ocurridoEn != null)
          'ocurridoEn': datos.ocurridoEn!.toUtc().toIso8601String(),
      };
}

/// Body de `PATCH /incidencias/:id/estado`.
///
/// Se manda solo `estado`, que es lo unico que valida `CambiarEstadoDto`
/// (`@IsIn(ESTADOS_INCIDENCIA)`). El `wire` viaja tal cual porque es lo que
/// espera el enum de Postgres.
class CambiarEstadoRequest {
  const CambiarEstadoRequest(this.estado);

  final EstadoIncidencia estado;

  Map<String, dynamic> toJson() => <String, dynamic>{'estado': estado.wire};
}

/// Body de `PATCH /incidencias/:id/asignar`.
///
/// El endpoint pertenece al modulo `incidencias` del backend, asi que el
/// request vive con los demas de esta feature y la feature `unidades` no
/// depende de esta.
class AsignarUnidadRequest {
  const AsignarUnidadRequest(this.unidadId);

  final String unidadId;

  Map<String, dynamic> toJson() => <String, dynamic>{'unidadId': unidadId};
}

/// Lee el id de `POST /incidencias`.
///
/// El `INSERT ... RETURNING id` devuelve solo el id, asi que no hay nada mas
/// que modelar: no se inventa una [Incidencia] a medias con codigo y estado
/// falsos. La pantalla confirma el alta y la lista se recarga al volver.
class IncidenciaCreadaDto {
  const IncidenciaCreadaDto({required this.id});

  final String id;

  factory IncidenciaCreadaDto.fromJson(Map<String, dynamic> json) =>
      IncidenciaCreadaDto(id: aTexto(json['id']));
}

/// Respuesta de `POST /incidencias/:id/evidencias`.
///
/// El `RETURNING` del service trae `id, tipo, url, hash, capturadoEn`.
class EvidenciaDto extends Equatable {
  const EvidenciaDto({
    required this.id,
    required this.url,
    this.tipo,
    this.hash,
    this.mimeType,
    this.capturadoEn,
  });

  final String id;
  final String url;
  final String? tipo;
  final String? hash;
  final String? mimeType;
  final DateTime? capturadoEn;

  factory EvidenciaDto.fromJson(Map<String, dynamic> json) => EvidenciaDto(
        id: aTexto(json['id']),
        url: aTexto(json['url']),
        tipo: aTextoOpcional(json['tipo']),
        hash: aTextoOpcional(json['hash']),
        mimeType: aTextoOpcional(json['mimeType']),
        capturadoEn: aFecha(json['capturadoEn']),
      );

  Evidencia toEntity() =>
      Evidencia(id: id, url: url, tipo: tipo, hash: hash, mimeType: mimeType, capturadoEn: capturadoEn);

  @override
  List<Object?> get props => [id, url, tipo, hash, mimeType, capturadoEn];
}

extension IncidenciaDtoX on IncidenciaDto {
  Incidencia toEntity() => Incidencia(
        id: id,
        codigo: codigo,
        tipo: tipo,
        tipoId: tipoId,
        estado: EstadoIncidencia.fromWire(estado),
        prioridad: Prioridad.fromWire(prioridad),
        latitud: latitud,
        longitud: longitud,
        ocurridoEn: ocurridoEn,
        evidencias: evidencias,
        descripcion: descripcion,
        referencia: referencia,
        unidadAsignadaId: unidadAsignadaId,
        reportadoPor: reportadoPor,
        reportadoPorNombre: reportadoPorNombre,
        atendidoEn: atendidoEn,
      );
}

extension PaginaIncidenciasDtoX on PaginaIncidenciasDto {
  PaginaIncidencias toEntity() => PaginaIncidencias(
        items: items.map((d) => d.toEntity()).toList(),
        total: meta.total,
        page: meta.page,
        limit: meta.limit,
      );
}