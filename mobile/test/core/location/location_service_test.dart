import 'dart:async';

import 'package:alerta_aguas_verdes/core/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble de [GeolocatorApi]: no toca el plugin, permite forzar fix, timeout,
/// ultima conocida o GPS apagado.
class _GeolocatorFake implements GeolocatorApi {
  _GeolocatorFake({
    this.activo = true,
    this.permisoInicial = PermisoUbicacion.permitido,
    this.fix,
    this.throwEnFix,
    this.ultima,
  });

  bool activo;
  PermisoUbicacion permisoInicial;
  GpsFix? fix;
  Object? throwEnFix;
  GpsFix? ultima;

  @override
  Future<bool> estaActivo() async => activo;

  @override
  Future<PermisoUbicacion> permiso() async => permisoInicial;

  @override
  Future<PermisoUbicacion> pedirPermiso() async => permisoInicial;

  @override
  Future<void> abrirAjustes() async {}

  @override
  Future<GpsFix> posicionActual({required Duration tiempoLimite}) async {
    if (throwEnFix != null) throw throwEnFix!;
    return fix!;
  }

  @override
  Future<GpsFix?> ultimaConocida() async => ultima;
}

void main() {
  test('fix fresco: Ok sin degradar', () async {
    final svc = LocationService(
      api: _GeolocatorFake(
        fix: const GpsFix(latitud: -1, longitud: -2, precisionMetros: 5),
      ),
    );

    final r = await svc.posicionActual();

    expect(r.isOk, isTrue);
    final v = r.valueOrNull!;
    expect(v.latitud, -1);
    expect(v.longitud, -2);
    expect(v.precisionMetros, 5);
    expect(v.degradada, isFalse);
  });

  test('timeout con ultima conocida: Ok degradada', () async {
    final svc = LocationService(
      api: _GeolocatorFake(
        throwEnFix: TimeoutException('timeout'),
        ultima: const GpsFix(latitud: -3, longitud: -4, precisionMetros: 50),
      ),
    );

    final r = await svc.posicionActual();

    expect(r.isOk, isTrue);
    final v = r.valueOrNull!;
    expect(v.latitud, -3);
    expect(v.longitud, -4);
    expect(v.degradada, isTrue);
  });

  test('timeout sin ultima conocida: Err', () async {
    final svc = LocationService(
      api: _GeolocatorFake(
        throwEnFix: TimeoutException('timeout'),
        ultima: null,
      ),
    );

    final r = await svc.posicionActual();

    expect(r.isErr, isTrue);
  });

  test('GPS apagado: Err', () async {
    final svc = LocationService(api: _GeolocatorFake(activo: false));

    final r = await svc.posicionActual();

    expect(r.isErr, isTrue);
  });

  test('permiso denegado para siempre: Err', () async {
    final svc = LocationService(
      api: _GeolocatorFake(permisoInicial: PermisoUbicacion.denegadoSiempre),
    );

    final r = await svc.posicionActual();

    expect(r.isErr, isTrue);
  });
}