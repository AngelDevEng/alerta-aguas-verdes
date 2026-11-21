import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

/// Capa base del mapa, centralizada para todas las pantallas.
///
/// Producción: MapTiler con API key. La key se inyecta en tiempo de compilación
/// con `--dart-define=MAPTILER_KEY=...` y nunca se escribe en el repo:
///
///   flutter run   --dart-define=MAPTILER_KEY=tu_key
///   flutter build --dart-define=MAPTILER_KEY=tu_key
///
/// Desarrollo: si no hay key se usa OpenStreetMap (sin API key) como fallback.
///
/// OpenStreetMap exige un `User-Agent` válido que identifique la app (nombre,
/// versión y contacto); sin él responde `403 Access blocked`. Ese mismo header se
/// usa con MapTiler.
class MapTiles {
  const MapTiles._();

  /// Identifica la app ante el proveedor de tiles (política de uso de OSM).
  static const String userAgent =
      'AlertaAguasVerdes/1.0.0 (+https://github.com/AngelDevEng/alerta-aguas-verdes; soporte@aguasverdes.gob.ec)';

  /// Key de MapTiler. Vacía = fallback a OSM (solo desarrollo).
  static const String maptilerKey = String.fromEnvironment('MAPTILER_KEY');

  static const String _plantillaOsm =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String _plantillaMapTiler =
      'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$maptilerKey';

  /// Cuánto caché de tiles se conserva en disco (250 MB).
  static const int _maxCacheBytes = 250 * 1024 * 1024;

  /// true si hay key de MapTiler configurada al compilar.
  static bool get usaMapTiler => maptilerKey.isNotEmpty;

  /// URL de la capa base según el proveedor activo.
  static String get urlTemplate =>
      usaMapTiler ? _plantillaMapTiler : _plantillaOsm;

  /// Texto de atribución (sin el símbolo © inicial: lo añade el widget).
  static String get atribucion => usaMapTiler
      ? 'MapTiler © OpenStreetMap contributors'
      : 'OpenStreetMap contributors';

  /// URL de los términos del proveedor activo.
  static String get urlAtribucion => usaMapTiler
      ? 'https://www.maptiler.com/copyright/'
      : 'https://www.openstreetmap.org/copyright';

  /// Crea la capa base con User-Agent propio y caché en disco.
  ///
  /// Llamar una sola vez por pantalla (guardarla en el `State`) y reutilizarla en
  /// cada `build`: crear un `NetworkTileProvider` nuevo en cada rebuild descarta
  /// el cliente HTTP y provoca peticiones de tiles en bucle.
  static TileLayer capaBase({double maxZoom = 19}) {
    return TileLayer(
      urlTemplate: urlTemplate,
      maxZoom: maxZoom,
      // Sobrescribe el `flutter_map (unknown)` por defecto. OSM bloquea ese UA.
      userAgentPackageName: userAgent,
      tileProvider: NetworkTileProvider(
        // Mapa mutable a proposito: TileLayer hace putIfAbsent sobre headers.
        headers: {'User-Agent': userAgent},
        cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
          maxCacheSize: _maxCacheBytes,
          // La key de MapTiler va en la URL; se quita de la clave de caché para
          // no guardarla en el nombre de los archivos ni invalidar todo el caché
          // si la key rota.
          tileKeyGenerator: _claveCache,
        ),
      ),
    );
  }

  /// Widget de atribución permanente (abajo a la derecha) con enlace a los
  /// términos del proveedor.
  static Widget atribucionWidget() => SimpleAttributionWidget(
        source: Text(atribucion),
        onTap: () => unawaited(
          launchUrl(Uri.parse(urlAtribucion), mode: LaunchMode.externalApplication),
        ),
      );

  static String _claveCache(String url) =>
      BuiltInMapCachingProvider.uuidTileKeyGenerator(url.split('?').first);
}