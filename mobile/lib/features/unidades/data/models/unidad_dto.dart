import '../../../../core/parsing/lector_json.dart';
import '../../domain/entities/unidad.dart';

/// Fila de `SELECT_BASE` en `unidades.service.ts`.
class UnidadDto {
  const UnidadDto({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.estado,
    this.placa,
    this.responsableId,
    this.latitud,
    this.longitud,
    this.ultimaActualizacion,
  });

  final String id;
  final String codigo;
  final String tipo;
  final String estado;
  final String? placa;
  final String? responsableId;
  final double? latitud;
  final double? longitud;
  final DateTime? ultimaActualizacion;

  factory UnidadDto.fromJson(Map<String, dynamic> json) => UnidadDto(
        id: aTexto(json['id']),
        codigo: aTexto(json['codigo']),
        tipo: aTextoOpcional(json['tipo']) ?? '',
        estado: aTextoOpcional(json['estado']) ?? '',
        placa: aTextoOpcional(json['placa']),
        responsableId: aTextoOpcional(json['responsableId']),
        latitud: aDobleOpcional(json['latitud']),
        longitud: aDobleOpcional(json['longitud']),
        ultimaActualizacion: aFecha(json['ultimaActualizacion']),
      );

  Unidad toEntity() => Unidad(
        id: id,
        codigo: codigo,
        tipo: TipoUnidad.fromWire(tipo),
        estado: EstadoUnidad.fromWire(estado),
        placa: placa,
        responsableId: responsableId,
        latitud: latitud,
        longitud: longitud,
        ultimaActualizacion: ultimaActualizacion,
      );
}

/// Fila de `fn_unidades_cercanas`: `id, codigo, tipo, distanciaM`.
///
/// Proyeccion distinta a [UnidadDto], y a proposito: `GET /unidades/cercanas`
/// no trae estado ni placa, asi que modelarla como [UnidadDto] obligaria a
/// asumir `estado: DISPONIBLE`, que es justo el dato que el operador necesita
/// para decidir.
class UnidadCercanaDto {
  const UnidadCercanaDto({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.distanciaM,
  });

  final String id;
  final String codigo;
  final String tipo;
  final double distanciaM;

  factory UnidadCercanaDto.fromJson(Map<String, dynamic> json) => UnidadCercanaDto(
        id: aTexto(json['id']),
        codigo: aTexto(json['codigo']),
        tipo: aTextoOpcional(json['tipo']) ?? '',
        distanciaM: aDoble(json['distanciaM']),
      );

  UnidadCercana toEntity() => UnidadCercana(
        id: id,
        codigo: codigo,
        tipo: TipoUnidad.fromWire(tipo),
        distanciaM: distanciaM,
      );
}

// El body de `PATCH /incidencias/:id/asignar` NO vive aca: ese endpoint es del
// modulo `incidencias` del backend, y su request DTO va junto a los demas de esa
// feature para que `unidades` no dependa de `incidencias`.