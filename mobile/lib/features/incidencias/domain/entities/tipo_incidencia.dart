import 'incidencia.dart';

/// Tipo de incidencia que se puede reportar.
class TipoIncidencia {
  const TipoIncidencia({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.prioridadSugerida,
  });

  final int id;

  /// Clave estable del tipo. Es lo unico que no depende del orden de insercion.
  final String codigo;
  final String nombre;

  /// Prioridad que el backend aplica si el reporte no manda ninguna.
  final Prioridad prioridadSugerida;

  @override
  String toString() => 'TipoIncidencia($id, $codigo)';
}

/// Catalogo de tipos de incidencia.
///
/// El backend no expone `GET /catalogos/tipos-incidencia`, asi que esta lista
/// replica `database/03_seed.sql`. Los `id` salen de `tipos_incidencia.id`,
/// que es `SMALLSERIAL`: en una base sembrada en fresco valen 1..7 en el orden
/// del INSERT.
///
/// Riesgo asumido: si alguien inserta o reordena tipos en la base, estos ids
/// quedan desalineados y el reporte se guardaria con el tipo equivocado. Por
/// eso el filtro de la lista NO usa esta lista (deriva los ids de lo que
/// devuelve el servidor) y solo se usa para ofrecer opciones al reportar,
/// donde el `tipoId` es obligatorio y no hay forma de discoverirlo.
///
/// Arreglo definitivo: agregar `GET /catalogos/tipos-incidencia` al backend y
/// reemplazar [porDefecto] por la respuesta. Es el unico bloque de este
/// archivo que habria que tocar.
abstract final class TiposIncidencia {
  static const porDefecto = <TipoIncidencia>[
    TipoIncidencia(
      id: 1,
      codigo: 'ROBO',
      nombre: 'Robo / hurto',
      prioridadSugerida: Prioridad.alta,
    ),
    TipoIncidencia(
      id: 2,
      codigo: 'RIA',
      nombre: 'Riña o disturbio',
      prioridadSugerida: Prioridad.media,
    ),
    TipoIncidencia(
      id: 3,
      codigo: 'SOSP',
      nombre: 'Persona sospechosa',
      prioridadSugerida: Prioridad.media,
    ),
    TipoIncidencia(
      id: 4,
      codigo: 'ACC',
      nombre: 'Accidente de tránsito',
      prioridadSugerida: Prioridad.alta,
    ),
    TipoIncidencia(
      id: 5,
      codigo: 'VIOL',
      nombre: 'Violencia familiar',
      prioridadSugerida: Prioridad.critica,
    ),
    TipoIncidencia(
      id: 6,
      codigo: 'RUIDO',
      nombre: 'Ruidos molestos',
      prioridadSugerida: Prioridad.baja,
    ),
    TipoIncidencia(
      id: 7,
      codigo: 'EMER',
      nombre: 'Emergencia médica',
      prioridadSugerida: Prioridad.critica,
    ),
  ];

  static TipoIncidencia? porId(int id) {
    for (final t in porDefecto) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// Formulario de reporte: lo que el usuario ingreso antes de enviar.
///
/// Vive en `domain/` y no es el body JSON: asi la pantalla no conoce los
/// nombres de campo del backend y [IncidenciaRequest] (en `data/`) puede
/// cambiar sin tocar el formulario.
class NuevaIncidencia {
  const NuevaIncidencia({
    required this.tipoId,
    required this.latitud,
    required this.longitud,
    this.descripcion,
    this.prioridad,
    this.referencia,
    this.ocurridoEn,
  });

  final int tipoId;
  final double latitud;
  final double longitud;
  final String? descripcion;

  /// Si es null el backend usa la prioridad del tipo.
  final Prioridad? prioridad;
  final String? referencia;
  final DateTime? ocurridoEn;

  /// El backend limita `referencia` a 200 caracteres.
  static const maxReferencia = 200;

  /// El `POST` devuelve 400 si falta `tipoId` o las coordenadas estan fuera de
  /// rango, asi que se valida antes de gastar la peticion.
  bool get esValido =>
      tipoId > 0 &&
      latitud >= -90 &&
      latitud <= 90 &&
      longitud >= -180 &&
      longitud <= 180 &&
      (referencia?.trim().length ?? 0) <= maxReferencia;
}

// `Evidencia` y `EvidenciaAdjunta` viven en `evidencia.dart`: son otro concepto
// del dominio y meterlos acá los dejaba sin cohesion con el catalogo de tipos.
