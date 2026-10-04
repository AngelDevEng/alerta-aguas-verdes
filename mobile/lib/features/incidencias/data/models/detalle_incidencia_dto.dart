import '../../../../core/parsing/lector_json.dart';
import '../../domain/entities/detalle_incidencia.dart';
import '../../domain/entities/evidencia.dart';
import '../../domain/entities/incidencia.dart';
import '../models/incidencias_dto.dart';

/// Parsea `GET /incidencias/:id`.
///
/// El backend responde la fila de `SELECT_BASE` y le agrega dos llaves mas que
/// la lista no trae:
///
/// ```json
/// { "id": "...", "codigo": "INC-0001", ...,
///   "historial": [ { "estadoAnterior": "...", "estadoNuevo": "...",
///                    "registradoEn": "...", "usuarioNombres": "...",
///                    "usuarioApellidos": "..." } ],
///   "evidenciasDetalle": [ { "id": "...", "tipo": "FOTO", "url": "...",
///                           "mimeType": "image/jpeg", "hash": "...",
///                           "capturadoEn": "..." } ] }
/// ```
///
/// [IncidenciaDto] ya sabe leer los campos comunes, asi que se reutiliza en vez
/// de duplicar los 16 campos de `SELECT_BASE`.
class DetalleIncidenciaDto {
  const DetalleIncidenciaDto({
    required this.incidencia,
    required this.historial,
    required this.evidencias,
  });

  final IncidenciaDto incidencia;
  final List<MovimientoEstadoDto> historial;
  final List<EvidenciaDetalleDto> evidencias;

  factory DetalleIncidenciaDto.fromJson(Map<String, dynamic> json) =>
      DetalleIncidenciaDto(
        incidencia: IncidenciaDto.fromJson(json),
        historial: aListaDeMapas(json['historial'])
            .map(MovimientoEstadoDto.fromJson)
            .toList(growable: false),
        evidencias: aListaDeMapas(json['evidenciasDetalle'])
            .map(EvidenciaDetalleDto.fromJson)
            .toList(growable: false),
      );

  DetalleIncidencia toEntity() => DetalleIncidencia(
        incidencia: incidencia.toEntity(),
        historial: historial.map((d) => d.toEntity()).toList(growable: false),
        evidencias: evidencias.map((d) => d.toEntity()).toList(growable: false),
      );
}

/// Fila de `historial_incidencia`.
///
/// Los nombres del usuario vienen de los dos campos del `LEFT JOIN` en cada
/// fila. Se concatenan aca, y no en el entidad, para que el criterio de unir
/// "Juan" + "Perez" viva una sola vez.
class MovimientoEstadoDto {
  const MovimientoEstadoDto({
    required this.estadoAnterior,
    required this.estadoNuevo,
    required this.registradoEn,
    this.usuario,
  });

  final EstadoIncidencia estadoAnterior;
  final EstadoIncidencia estadoNuevo;
  final DateTime registradoEn;
  final String? usuario;

  factory MovimientoEstadoDto.fromJson(Map<String, dynamic> json) =>
      MovimientoEstadoDto(
        estadoAnterior: EstadoIncidencia.fromWire(aTextoOpcional(json['estadoAnterior'])),
        estadoNuevo: EstadoIncidencia.fromWire(aTextoOpcional(json['estadoNuevo'])),
        registradoEn: aFecha(json['registradoEn']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        usuario: _juntar(
          aTextoOpcional(json['usuarioNombres']),
          aTextoOpcional(json['usuarioApellidos']),
        ),
      );

  MovimientoEstado toEntity() => MovimientoEstado(
        estadoAnterior: estadoAnterior,
        estadoNuevo: estadoNuevo,
        registradoEn: registradoEn,
        usuario: usuario,
      );

  /// Une nombre y apellido, o null si el `LEFT JOIN` no trajo ninguno.
  static String? _juntar(String? nombres, String? apellidos) {
    final partes = [nombres, apellidos]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return partes.isEmpty ? null : partes.join(' ');
  }
}

/// Fila de `evidenciasDetalle`.
///
/// Es el mismo registro que devuelve `POST /incidencias/:id/evidencias` pero con
/// dos campos mas, asi que se extiende en vez de duplicar.
class EvidenciaDetalleDto {
  const EvidenciaDetalleDto({
    required this.id,
    required this.url,
    this.tipo,
    this.mimeType,
    this.hash,
    this.capturadoEn,
  });

  final String id;
  final String url;
  final String? tipo;
  final String? mimeType;
  final String? hash;
  final DateTime? capturadoEn;

  factory EvidenciaDetalleDto.fromJson(Map<String, dynamic> json) =>
      EvidenciaDetalleDto(
        id: aTexto(json['id']),
        url: aTexto(json['url']),
        tipo: aTextoOpcional(json['tipo']),
        mimeType: aTextoOpcional(json['mimeType']),
        hash: aTextoOpcional(json['hash']),
        capturadoEn: aFecha(json['capturadoEn']),
      );

  Evidencia toEntity() => Evidencia(
        id: id,
        url: url,
        tipo: tipo,
        mimeType: mimeType,
        hash: hash,
        capturadoEn: capturadoEn,
      );
}