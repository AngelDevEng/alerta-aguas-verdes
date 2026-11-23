import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'logging_http_client.dart';

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
      'AlertaAguasVerdes/1.0.0 (+https://github.com/AngelDevEng/alerta-aguas-verdes; soporte@muniaguasverdes.gob.pe)';

  /// Key de MapTiler. Vacía = fallback a OSM (solo desarrollo).
  static const String maptilerKey = String.fromEnvironment('MAPTILER_KEY');

  static const String _plantillaOsm =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String _plantillaMapTiler =
      'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$maptilerKey';

  /// Cuánto caché de tiles se conserva en disco (250 MB).
  static const int _maxCacheBytes = 250 * 1024 * 1024;

  /// Versión del caché. Subirla cambia el directorio y la clave de cada tile,
  /// invalidando cualquier tile cacheado por una versión anterior.
  static const String _versionCache = 'v2';

  /// Directorio base del caché. Lo fija [init] antes de `runApp`.
  static String? _cacheDirectory;

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

  /// Fija el directorio de caché versionado. Debe llamarse una vez antes de
  /// `runApp` (ver `main.dart`).
  ///
  /// En web no hay caché de disco: `path_provider` no soporta
  /// `getApplicationCacheDirectory`.
  static Future<void> init() async {
    if (kIsWeb || _cacheDirectory != null) return;
    final dir = await getApplicationCacheDirectory();
    _cacheDirectory = '${dir.path}/map_tiles_$_versionCache';
    debugPrint('[MAPA] cache dir: $_cacheDirectory');
  }

  /// Crea la capa base con User-Agent propio y caché en disco.
  ///
  /// Llamar una sola vez por pantalla (guardarla en el `State`) y reutilizarla en
  /// cada `build`: crear un `NetworkTileProvider` nuevo en cada rebuild descarta
  /// el cliente HTTP y provoca peticiones de tiles en bucle.
  static TileLayer capaBase({double maxZoom = 19}) {
    // TEMPORAL: diagnóstico del 403. Solo en debug y sin la key de MapTiler.
    if (kDebugMode) {
      debugPrint('[MAPA] proveedor: ${usaMapTiler ? 'MapTiler' : 'OSM (fallback desarrollo)'}');
      debugPrint('[MAPA] MAPTILER_KEY: ${maptilerKey.isEmpty ? '(no inyectada)' : '(inyectada)'}');
      debugPrint('[MAPA] User-Agent: $userAgent');
    }

    return TileLayer(
      urlTemplate: urlTemplate,
      maxZoom: maxZoom,
      // Sobrescribe el `flutter_map (unknown)` por defecto. OSM bloquea ese UA.
      userAgentPackageName: userAgent,
      // TEMPORAL: registra URL, status y UA de cada tile fallido.
      errorTileCallback: _logErrorTile,
      tileProvider: NetworkTileProvider(
        // Mapa mutable a proposito: TileLayer hace putIfAbsent sobre headers.
        headers: {'User-Agent': userAgent},
        // TEMPORAL: envuelve el cliente para ver el UA real que sale a la red.
        httpClient: LoggingHttpClient(),
        // No mostrar el cuerpo de un error HTTP como imagen: OSM devuelve un PNG
        // "Access blocked" con status 403 y antes se decodificaba y se veia como
        // si fuera un tile. Ahora el 403 dispara errorTileCallback.
        attemptDecodeOfHttpErrorResponses: false,
        cachingProvider: _cachingProvider(),
      ),
    );
  }

  /// Caché en disco. Solo se escriben respuestas 200 (flutter_map,
  /// `image_provider.dart:256-258`); los 403 nunca se guardan.
  /// En web se omite: no hay filesystem persistente compatible.
  static MapCachingProvider? _cachingProvider() {
    if (kIsWeb) return null;
    return BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: _cacheDirectory,
      maxCacheSize: _maxCacheBytes,
      // La key de MapTiler va en la URL; se quita de la clave de caché para no
      // guardarla en el nombre de los archivos ni invalidar todo el caché si la
      // key rota. El prefijo de versión invalida cachés anteriores.
      tileKeyGenerator: _claveCache,
    );
  }

  static void _logErrorTile(TileImage tile, Object error, StackTrace? stackTrace) {
    if (!kDebugMode) return;
    final c = tile.coordinates;
    // `mensajeErrorTile` nunca incluye la URL completa: la de MapTiler lleva
    // `?key=<MAPTILER_KEY>` y no debe aparecer en los logs.
    debugPrint(mensajeErrorTile(c.z, c.x, c.y, error));
    if (stackTrace != null) {
      debugPrint('[MAPA]   stack=$stackTrace');
    }
  }

  /// Widget de atribución permanente (abajo a la derecha) con enlace a los
  /// términos del proveedor.
  static Widget atribucionWidget() => SimpleAttributionWidget(
        source: Text(atribucion),
        onTap: () => unawaited(
          launchUrl(Uri.parse(urlAtribucion), mode: LaunchMode.externalApplication),
        ),
      );

  static String _claveCache(String url) => BuiltInMapCachingProvider
        .uuidTileKeyGenerator('$_versionCache|${url.split('?').first}');
}

/// Descripcion sanitizada de un tile fallido para los logs.
///
/// Solo expone `status` y el `path` del error: nunca la URL completa, porque la
/// de MapTiler incluye `?key=<MAPTILER_KEY>`. `NetworkImageLoadException`
/// tampoco se imprime con `$error` (su `toString()` incluye el `uri`).
@visibleForTesting
String mensajeErrorTile(int z, int x, int y, Object error) {
  final base = '[MAPA] ERROR tile z$z/$x/$y';
  if (error is NetworkImageLoadException) {
    return '$base: status=${error.statusCode} path=${error.uri.path}';
  }
  return '$base: ${error.runtimeType}';
}