import '../../../../core/error/result.dart';

/// Una foto aun sin subir, adjunta al reporte.
///
/// Vive en `domain/` y no es el body multipart: la pantalla no debe saber que
/// el backend espera un campo llamado `archivo`.
class EvidenciaAdjunta {
  const EvidenciaAdjunta({
    required this.ruta,
    required this.nombre,
    this.latitud,
    this.longitud,
  });

  /// Ruta local del archivo, tal como la devuelve `image_picker`.
  final String ruta;

  /// Nombre con extension. El backend lo usa para la extension del objeto en
  /// Supabase, asi que no puede inventarse.
  final String nombre;

  /// Geolocalizacion de la foto. Opcional: el backend solo la guarda si ambos
  /// valores son finitos.
  final double? latitud;
  final double? longitud;

  /// Limite de multer en el backend. Pasarse produce un 413 y la foto se pierde.
  static const maxBytes = 15 * 1024 * 1024;

  /// Fallas de validacion antes de gastar la subida.
  ///
  /// Se validan aca y no en el widget porque el mismo chequeo corre en el
  /// reintento de evidencias parciales, que no vuelve a pasar por la UI.
  Result<void> validar() {
    if (nombre.trim().isEmpty) {
      return const Err<void>(LocalFailure('La foto no tiene nombre.'));
    }
    if (ruta.trim().isEmpty) {
      return const Err<void>(LocalFailure('La foto no tiene una ruta legible.'));
    }
    final tieneGps = latitud != null && longitud != null;
    if (tieneGps && (latitud! < -90 || latitud! > 90 || longitud! < -180 || longitud! > 180)) {
      return const Err<void>(
        LocalFailure('La foto trae coordenadas fuera de rango.'),
      );
    }
    return const Ok<void>(null);
  }
}

/// Evidencia ya registrada en el servidor.
///
/// La usan dos endpoints distintos con el mismo destino: el alta de cada foto
/// devuelve `RETURNING id, tipo, url, hash` y el detalle agrega
/// `mimeType` y `capturadoEn`. Por eso los ultimos dos son opcionales en vez de
/// inventar un constructor con todos los campos y valores falsos.
class Evidencia {
  const Evidencia({
    required this.id,
    required this.url,
    this.tipo,
    this.hash,
    this.mimeType,
    this.capturadoEn,
  });

  final String id;
  final String url;

  /// Tipo de evidencia (`FOTO`, `VIDEO`, `AUDIO`).
  final String? tipo;

  /// SHA-256 con el que el backend deduplica. Si se resubite el mismo archivo,
  /// responde 409.
  final String? hash;

  final String? mimeType;
  final DateTime? capturadoEn;

  /// MIME que acepta el backend. Fuente: filtro de multer en
  /// `incidencias.controller.ts`.
  static const mimesAceptados = <String>{
    'image/jpeg',
    'image/png',
    'video/mp4',
    'audio/mpeg',
    'audio/mp4',
  };

  /// Si se puede mostrar en una miniatura.
  ///
  /// Antes de tocar `url_publica` hay que preguntar aca: el bucket de
  /// Supabase entrega las evidencias con la policy de lectura que se haya
  /// configurado, y un 403 en la imagen se ve igual que un archivo roto.
  bool get esImagen => mimeType?.startsWith('image/') ?? false;

  bool get esVideo => mimeType?.startsWith('video/') ?? false;

  bool get esAudio => mimeType?.startsWith('audio/') ?? false;

  /// Texto corto para el listado de evidencias.
  String get etiqueta {
    if (esVideo) return 'Video';
    if (esAudio) return 'Audio';
    if (esImagen) return 'Foto';
    if (mimeType != null) return mimeType!;
    // Sin MIME no se puede clasificar: se muestra el tipo crudo del backend, que
    // es mejor que inventar "Foto".
    return tipo?.toUpperCase() ?? 'Evidencia';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Evidencia && other.id == id && other.hash == hash;

  @override
  int get hashCode => Object.hash(id, hash);

  @override
  String toString() => 'Evidencia($id, $mimeType)';
}