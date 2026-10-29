import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../../../core/parsing/lector_json.dart';
import '../../domain/entities/incidencia.dart';
import '../../domain/entities/incidencia_mapa.dart';

/// DTO de `GET /incidencias/geojson`.
///
/// El backend devuelve `{ type: 'FeatureCollection', features: [...] }` donde
/// cada feature la arma `v_incidencias_geojson`
/// (`database/02_indices_triggers.sql:71`) como
/// `{ type: 'Feature', geometry: { type: 'Point', coordinates: [lon, lat] },
/// properties: { codigo, tipo, estado, prioridad } }`.
///
/// El orden de coordenadas es de GeoJSON: longitud primero, latitud despues.
/// Es al reves que en toda la API, que manda `latitud`/`longitud` sueltos, y
/// mezclarlos deja los puntos en el oceano sin que nadie se entere.
class IncidenciaMapaDto extends Equatable {
  const IncidenciaMapaDto({
    required this.codigo,
    required this.tipo,
    required this.estado,
    required this.prioridad,
    required this.latitud,
    required this.longitud,
  });

  final String codigo;
  final String tipo;

  /// Los strings crudos del `wire`; los enum se resuelven al convertir, igual
  /// que en `IncidenciaDto`.
  final String estado;
  final String prioridad;

  final double latitud;
  final double longitud;

  /// Lee una `FeatureCollection` completa.
  ///
  /// Si la respuesta no tiene forma de `FeatureCollection` lanza
  /// [NetworkFailure]: es un contrato roto y la pantalla debe poder decirlo.
  /// Un feature individual malformado en cambio se descarta: el mapa sigue
  /// sirviendo con los 999 puntos buenos.
  static List<IncidenciaMapa> deFeatureCollection(dynamic data) {
    if (data is! Map || data['type'] != 'FeatureCollection') {
      throw const NetworkFailure(
        'El servidor devolvio una respuesta inesperada.',
      );
    }
    final features = data['features'];
    if (features is! List) {
      throw const NetworkFailure(
        'El servidor devolvio una respuesta inesperada.',
      );
    }
    return [
      for (final f in aListaDeMapas(features))
        if (deFeature(f) case final IncidenciaMapaDto dto) dto.toEntity(),
    ];
  }

  /// Lee un solo punto. Devuelve `null` si el feature esta roto.
  static IncidenciaMapaDto? deFeature(Map<String, dynamic> json) {
    final geometria = json['geometry'];
    if (geometria is! Map || geometria['type'] != 'Point') return null;

    final coords = geometria['coordinates'];
    if (coords is! List || coords.length < 2) return null;

    final longitud = aDobleOpcional(coords[0]);
    final latitud = aDobleOpcional(coords[1]);
    if (latitud == null || longitud == null) return null;

    // Fuera de rango = punto inutilizable en el mapa. Se descarta igual que
    // un geometry malformado, no se lanza: un unico registro sucio no puede
    // borrar la capa entera.
    if (!latitud.isFinite ||
        !longitud.isFinite ||
        latitud.abs() > 90 ||
        longitud.abs() > 180) {
      return null;
    }

    final props = json['properties'] is Map
        ? Map<String, dynamic>.from(json['properties'] as Map)
        : const <String, dynamic>{};

    final codigo = aTextoOpcional(props['codigo'])?.trim() ?? '';
    if (codigo.isEmpty) return null;

    return IncidenciaMapaDto(
      codigo: codigo,
      tipo: aTexto(props['tipo']),
      estado: aTextoOpcional(props['estado']) ?? '',
      prioridad: aTextoOpcional(props['prioridad']) ?? '',
      latitud: latitud,
      longitud: longitud,
    );
  }

  IncidenciaMapa toEntity() => IncidenciaMapa(
        codigo: codigo,
        tipo: tipo,
        estado: EstadoIncidencia.fromWire(estado),
        prioridad: Prioridad.fromWire(prioridad),
        latitud: latitud,
        longitud: longitud,
      );

  @override
  List<Object?> get props => [codigo, tipo, estado, prioridad, latitud, longitud];
}
