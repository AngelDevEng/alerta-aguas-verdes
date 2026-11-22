import 'dart:math';

/// Clave de idempotencia estable por envio de SOS (UUID v4).
///
/// Se genera una sola vez por SOS y se conserva mientras el envio se reintenta
/// (mala señal, timeout, reanudar la app): el backend la usa para devolver la
/// MISMA alerta en vez de crear otra. Solo cambia cuando el usuario inicia una
/// SOS nueva.
String nuevoIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  // Version 4 (aleatoria) y variante RFC 4122.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}