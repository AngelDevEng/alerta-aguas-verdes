import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda la sesion anonima del ciudadano (alerta + token de seguimiento).
///
/// Va en un almacenamiento seguro aparte de [TokenStore] a proposito: el JWT
/// del operador y el token del ciudadano son identidades distintas y no deben
/// compartir ciclo de vida. El ciudadano no tiene JWT, asi que el token del
/// SOS es lo unico que le permite volver a `GET /alertas/:id/seguimiento`.
class SosSessionStore {
  SosSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _kAlertaId = 'sos_alerta_id';
  static const _kToken = 'sos_session_token';
  static const _kDeviceId = 'sos_device_id';

  Future<void> save({required String alertaId, required String sessionToken}) async {
    await _storage.write(key: _kAlertaId, value: alertaId);
    await _storage.write(key: _kToken, value: sessionToken);
  }

  /// Identificador estable del dispositivo para `X-Device-Id`.
  ///
  /// Se genera una sola vez y se guarda en el almacenamiento seguro: el backend
  /// lo usa para devolver la SOS ya activa en vez de crear otra. No es un IMEI
  /// ni un identificador de hardware; es un opaco local.
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final id = List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: _kDeviceId, value: id);
    return id;
  }

  Future<({String alertaId, String sessionToken})?> read() async {
    final id = await _storage.read(key: _kAlertaId);
    final token = await _storage.read(key: _kToken);
    if (id == null || token == null || id.isEmpty || token.isEmpty) return null;
    return (alertaId: id, sessionToken: token);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAlertaId);
    await _storage.delete(key: _kToken);
  }
}