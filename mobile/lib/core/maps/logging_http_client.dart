import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

/// Cliente HTTP temporal para diagnosticar el 403 de los tiles.
///
/// Registra, por cada peticion de tile:
///   - metodo y path (SIN query: la URL de MapTiler lleva `?key=...`),
///   - el `User-Agent` que realmente se envia,
///   - el status code y el content-type de la respuesta.
///
/// Solo registra en `kDebugMode`: en release no emite nada (evita filtrar la
/// key de MapTiler a los logs).
///
/// ELIMINAR junto con los `debugPrint('[MAPA] ...')` de `map_tiles.dart` cuando
/// el diagnostico termine.
class LoggingHttpClient extends BaseClient {
  LoggingHttpClient({Client? inner}) : _inner = inner ?? Client();

  final Client _inner;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final ua = request.headers['User-Agent'] ?? '(sin User-Agent)';
    if (kDebugMode) {
      // Sin query: la URL de MapTiler incluye `?key=<MAPTILER_KEY>`.
      final path = request.url.path;
      debugPrint('[MAPA] ${request.method} $path');
      debugPrint('[MAPA]   User-Agent enviado: $ua');
    }

    final response = await _inner.send(request);

    if (kDebugMode) {
      final length = response.headers['content-length'] ??
          (response.contentLength == null ? 'chunked' : '${response.contentLength}');
      debugPrint(
        '[MAPA]   <- ${response.statusCode} '
        '${response.headers['content-type'] ?? 'sin content-type'} len=$length',
      );
    }
    return response;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}