import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Payload del SOS que todavia no fue confirmado por la central.
///
/// Se persiste para que un reintento (o reabrir la app) reenvie EXACTAMENTE la
/// misma alerta: misma [idempotencyKey], misma posicion, mismo `sinUbicacion`.
/// Asi el backend puede deduplicar y el usuario no genera alertas repetidas.
///
/// [creadoEn] marca cuando se creo el pendiente. Pasado [SosStore.ttlPendiente]
/// el pendiente se descarta: reintentar una SOS de hace horas ya no tiene
/// sentido (la central la habra cerrado o el ciudadano ya se movio).
class PendingSos {
  PendingSos({
    required this.idempotencyKey,
    required this.latitud,
    required this.longitud,
    this.precisionM,
    this.sinUbicacion = false,
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  final String idempotencyKey;
  final double latitud;
  final double longitud;
  final double? precisionM;
  final bool sinUbicacion;
  final DateTime creadoEn;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'idempotencyKey': idempotencyKey,
        'latitud': latitud,
        'longitud': longitud,
        if (precisionM != null) 'precisionM': precisionM,
        'sinUbicacion': sinUbicacion,
        'creadoEn': creadoEn.toIso8601String(),
      };

  factory PendingSos.fromJson(Map<String, dynamic> json) {
    final precision = json['precisionM'];
    final creado = json['creadoEn'];
    return PendingSos(
      idempotencyKey: json['idempotencyKey'] as String,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      precisionM: precision is num ? precision.toDouble() : null,
      sinUbicacion: json['sinUbicacion'] as bool? ?? false,
      creadoEn: creado is String ? DateTime.tryParse(creado) ?? DateTime.now() : DateTime.now(),
    );
  }
}

/// Persistencia del SOS y su sesion anonima.
///
/// Interfaz (no clase) para que el [SosBloc] dependa de un contrato y los
/// tests puedan usar un doble en memoria. La implementacion real es
/// [SosSessionStore] sobre almacenamiento seguro.
abstract interface class SosStore {
  /// Identificador estable del dispositivo para `X-Device-Id`.
  Future<String> deviceId();

  Future<void> save({required String alertaId, required String sessionToken});
  Future<({String alertaId, String sessionToken})?> read();
  Future<void> clear();

  /// Vida util del SOS pendiente. Pasado este tiempo, [readPending] devuelve
  /// null: reintentar una SOS vieja no tiene sentido.
  static const Duration ttlPendiente = Duration(minutes: 5);

  Future<void> savePending(PendingSos pending);

  /// Devuelve el pendiente solo si no expiro (ver [ttlPendiente]). Si expiro,
  /// lo limpia y devuelve null.
  Future<PendingSos?> readPending();

  /// true si habia un pendiente en disco pero [readPending] lo descarto por
  /// expiracion (TTL). Se usa para avisar "No se pudo enviar, llama ahora".
  Future<bool> hayPendienteExpirado();

  Future<void> clearPending();
}

/// Guarda la sesion anonima del ciudadano (alerta + token de seguimiento) y el
/// SOS pendiente de confirmacion.
///
/// Va en un almacenamiento seguro aparte de [TokenStore] a proposito: el JWT
/// del operador y el token del ciudadano son identidades distintas y no deben
/// compartir ciclo de vida. El ciudadano no tiene JWT, asi que el token del
/// SOS es lo unico que le permite volver a `GET /alertas/:id/seguimiento`.
class SosSessionStore implements SosStore {
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
  static const _kPending = 'sos_pending';

  @override
  Future<void> save({required String alertaId, required String sessionToken}) async {
    await _storage.write(key: _kAlertaId, value: alertaId);
    await _storage.write(key: _kToken, value: sessionToken);
  }

  /// Identificador estable del dispositivo para `X-Device-Id`.
  ///
  /// Se genera una sola vez y se guarda en el almacenamiento seguro: el backend
  /// lo usa para devolver la SOS ya activa en vez de crear otra. No es un IMEI
  /// ni un identificador de hardware; es un opaco local.
  @override
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

  @override
  Future<({String alertaId, String sessionToken})?> read() async {
    final idVal = await _storage.read(key: _kAlertaId);
    final token = await _storage.read(key: _kToken);
    if (idVal == null || token == null || idVal.isEmpty || token.isEmpty) return null;
    return (alertaId: idVal, sessionToken: token);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAlertaId);
    await _storage.delete(key: _kToken);
  }

  @override
  Future<void> savePending(PendingSos pending) async {
    await _storage.write(key: _kPending, value: jsonEncode(pending.toJson()));
  }

  @override
  Future<PendingSos?> readPending() async {
    final raw = await _storage.read(key: _kPending);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final pendiente = PendingSos.fromJson(Map<String, dynamic>.from(decoded));
      // TTL: un pendiente mas viejo que ttlPendiente se descarta. Reintentar
      // una SOS de hace media hora ya no representa la emergencia actual.
      if (DateTime.now().difference(pendiente.creadoEn) > SosStore.ttlPendiente) {
        await _storage.delete(key: _kPending);
        return null;
      }
      return pendiente;
    } catch (_) {
      // JSON corrupto: se ignora como si no hubiera pendiente.
      return null;
    }
  }

  @override
  Future<bool> hayPendienteExpirado() async {
    final raw = await _storage.read(key: _kPending);
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final pendiente = PendingSos.fromJson(Map<String, dynamic>.from(decoded));
      // Solo cuenta como "expirado" si tiene creadoEn y supero el TTL. Un
      // pendiente sin creadoEn (formato viejo) se considera no expirado para
      // no romper la migracion.
      if (DateTime.now().difference(pendiente.creadoEn) > SosStore.ttlPendiente) {
        await _storage.delete(key: _kPending);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearPending() async {
    await _storage.delete(key: _kPending);
  }
}