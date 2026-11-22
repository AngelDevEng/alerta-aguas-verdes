import 'dart:async';

import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/core/location/location_service.dart';
import 'package:alerta_aguas_verdes/core/storage/sos_session_store.dart';
import 'package:alerta_aguas_verdes/features/alertas/domain/entities/alerta_sos.dart';
import 'package:alerta_aguas_verdes/features/alertas/domain/repositories/alerta_repository.dart';
import 'package:alerta_aguas_verdes/features/alertas/domain/usecases/alerta_usecases.dart';
import 'package:alerta_aguas_verdes/features/alertas/presentation/bloc/sos_bloc.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/entities/login_request.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/entities/usuario.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/repositories/auth_repository.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/usecases/auth_usecases.dart';
import 'package:alerta_aguas_verdes/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:alerta_aguas_verdes/features/catalogos/domain/entities/catalogo.dart';
import 'package:alerta_aguas_verdes/features/catalogos/domain/repositories/catalogo_repository.dart';
import 'package:alerta_aguas_verdes/features/catalogos/domain/usecases/catalogo_usecases.dart';
import 'package:alerta_aguas_verdes/features/catalogos/presentation/bloc/catalogos_bloc.dart';
import 'package:alerta_aguas_verdes/features/home/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Doble del repositorio de autenticacion (mismo esquema que auth_bloc_test).
class _AuthFalso implements AuthRepository {
  _AuthFalso(this.usuario);

  final Usuario usuario;

  @override
  Future<AuthSession> login(LoginRequest request) async =>
      AuthSession(usuario: usuario);

  @override
  Future<AuthSession> loginPorPlaca(LoginPlacaRequest request) async =>
      AuthSession(usuario: usuario);

  @override
  Future<Usuario?> restoreSession() async => usuario;

  @override
  Future<Usuario> me() async => usuario;

  @override
  Future<void> logout(String? refreshToken) async {}
}

/// Doble del repositorio de catalogos: el home llama a la comisaria y al
/// serenazgo con el telefono del catalogo cargado aqui.
class _CatalogoFalso implements CatalogoRepository {
  const _CatalogoFalso();

  static const _contactos = [
    ContactoEmergencia(
      id: 1,
      nombre: 'Comisaría PNP',
      telefono: '51957822184',
      esWhatsapp: false,
    ),
    ContactoEmergencia(
      id: 2,
      nombre: 'Serenazgo',
      telefono: '51967404172',
      esWhatsapp: false,
    ),
    ContactoEmergencia(
      id: 3,
      nombre: 'WhatsApp Serenazgo',
      telefono: '51967404172',
      esWhatsapp: true,
    ),
  ];

  @override
  Future<Result<List<ContactoEmergencia>>> emergencias() async =>
      const Ok(_contactos);

  @override
  Future<Result<List<ContactoEmergencia>>> emergenciasWhatsapp() async =>
      const Ok([]);

  @override
  Future<Result<List<Asociacion>>> asociaciones() async => const Ok([]);
}

/// Doble del servicio de ubicacion para el flujo del SOS.
class _LocationFake implements LocationService {
  _LocationFake({this.posicion, this.falla});

  final PosicionActual? posicion;
  final Failure? falla;

  @override
  Future<Result<PosicionActual>> posicionActual() async =>
      falla != null ? Err(falla!) : Ok(posicion!);
}

/// Doble del repositorio de alertas: cuenta toques y captura lo enviado.
class _AlertasFalsa implements AlertaRepository {
  _AlertasFalsa({this.puerta});

  /// Compuerta manual: la peticion no responde hasta que el test la complete.
  /// Permite probar el banner de "Llamar ahora" con un envio en curso y evita
  /// dejar un Timer real pendiente al terminar el test.
  final Completer<void>? puerta;

  int llamadas = 0;
  double? latitudEnviada;
  bool? sinUbicacionEnviada;

  @override
  Future<Result<AlertaSos>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
    bool sinUbicacion = false,
    String? idempotencyKey,
  }) async {
    llamadas++;
    latitudEnviada = latitud;
    sinUbicacionEnviada = sinUbicacion;
    if (puerta != null) await puerta!.future;
    return const Ok(AlertaSos(alertaId: 'alerta-1', sessionToken: 'token-1'));
  }

  @override
  Future<Result<Map<String, dynamic>>> cambiarEstado(String id, String estado) async =>
      Ok({'id': id, 'estado': estado});
}

/// Almacen en memoria del SOS (el home no lo usa directo, pero el bloc si).
class _StoreFalso implements SosStore {
  PendingSos? pending;
  String? alertaId;
  String? token;

  @override
  Future<String> deviceId() async => 'device-1';

  @override
  Future<void> save({required String alertaId, required String sessionToken}) async {
    this.alertaId = alertaId;
    token = sessionToken;
  }

  @override
  Future<({String alertaId, String sessionToken})?> read() async =>
      (alertaId != null && token != null)
          ? (alertaId: alertaId!, sessionToken: token!)
          : null;

  @override
  Future<void> clear() async {
    alertaId = null;
    token = null;
  }

  @override
  Future<void> savePending(PendingSos value) async => pending = value;

  @override
  Future<PendingSos?> readPending() async => pending;

  @override
  Future<bool> hayPendienteExpirado() async => false;

  @override
  Future<void> clearPending() async => pending = null;

  @override
  Future<void> saveClaveCancelada(String idempotencyKey) async {}

  @override
  Future<String?> readClaveCancelada() async => null;

  @override
  Future<void> clearClaveCancelada() async {}
}

const _admin = Usuario(
  id: 'u-admin',
  dni: '00000002',
  nombreCompleto: 'Admin Prueba',
  rol: 'ADMIN',
);

/// Arma la pantalla con la sesion ya activa.
///
/// Los doubles del SOS son opcionales: si no se pasan, se usa un GPS y un
/// backend sanos para que cualquier test que solo verifique el menu no tenga
/// que pensar en el flujo.
Future<void> _mostrar(
  WidgetTester tester, {
  LocationService? location,
  AlertaRepository? alertas,
}) async {
  final auth = _AuthFalso(_admin);
  GetIt.I.registerLazySingleton<AuthBloc>(
    () => AuthBloc(
      LoginUseCase(auth),
      LogoutUseCase(auth),
      RestoreSessionUseCase(auth),
      VerifySessionUseCase(auth),
      LoginPorPlacaUseCase(auth),
    ),
  );
  GetIt.I.registerFactory<CatalogosBloc>(
    () => CatalogosBloc(const ObtenerEmergenciasUseCase(_CatalogoFalso())),
  );
  final sos = SosBloc(
    location ??
        _LocationFake(
          posicion: const PosicionActual(
            latitud: -3.4825,
            longitud: -80.245,
            precisionMetros: 5,
          ),
        ),
    EnviarSosUseCase(alertas ?? _AlertasFalsa()),
    _StoreFalso(),
  );
  GetIt.I.registerFactory<SosBloc>(() => sos);

  // El escudo usa `context.go('/login')`; sin GoRouter la prueba reventaba
  // con "No GoRouter found in context".
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(
          body: Center(child: Text('Login')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() async {
    await GetIt.I.reset();
  });

  testWidgets('replica 1:1 el launcher del legacy (header, SOS, grilla 2x2 y '
      'buscador)', (tester) async {
    await _mostrar(tester);

    // Header (activity_panico_main.xml:38-65).
    expect(find.text('ALERTA'), findsOneWidget);
    expect(find.text('AGUAS VERDES'), findsOneWidget);
    expect(find.byKey(const Key('home_escudo')), findsOneWidget);

    // SOS + tarjetas.
    expect(find.byKey(const Key('menu_sos')), findsOneWidget);
    expect(find.byKey(const Key('menu_comisaria')), findsOneWidget);
    expect(find.byKey(const Key('menu_serenazgo')), findsOneWidget);
    expect(find.byKey(const Key('menu_incidencias')), findsOneWidget);
    expect(find.byKey(const Key('menu_otras_emergencias')), findsOneWidget);
    expect(find.text('POLICIA PNP'), findsOneWidget);
    expect(find.text('SERENAZGO'), findsOneWidget);
    expect(find.text('INCIDENTES'), findsOneWidget);
    expect(find.text('EMERGENCIAS\nMÚLTIPLES'), findsOneWidget);

    // Footer de busqueda (:268-313).
    expect(find.text('Buscar:'), findsOneWidget);
    expect(find.byKey(const Key('placa_input')), findsOneWidget);
    expect(find.byKey(const Key('menu_buscar')), findsOneWidget);

    // El menu del viejo legacy Kotlin ya no esta: 1:1 con este launcher.
    expect(find.byKey(const Key('menu_reportar')), findsNothing);
    expect(find.byKey(const Key('menu_mapa_calor')), findsNothing);
    expect(find.byKey(const Key('menu_placa')), findsNothing);
    expect(find.byKey(const Key('menu_rastreo')), findsNothing);
  });

  testWidgets('el escudo lleva al login (stand-in de admin())', (tester) async {
    await _mostrar(tester);

    await tester.tap(find.byKey(const Key('home_escudo')));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('tocar SOS envia la alerta y confirma con el texto del legacy',
      (tester) async {
    final alertas = _AlertasFalsa();
    await _mostrar(tester, alertas: alertas);

    await tester.tap(find.byKey(const Key('menu_sos')));
    // La navegacion a RastreoCiudadanoPage deja un Timer.periodic vivo; no se
    // usa pumpAndSettle para no esperar a que el timer se agote.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(alertas.llamadas, 1);
    expect(alertas.latitudEnviada, isNotNull);
    expect(find.text('Auxilio enviado a central'), findsOneWidget);
  });

  testWidgets('si el GPS falla, el SOS se envia igual (sin ubicacion)',
      (tester) async {
    final alertas = _AlertasFalsa();
    await _mostrar(
      tester,
      alertas: alertas,
      location: _LocationFake(
        falla: const LocalFailure(
          'El GPS esta apagado. Activalo para ubicar la incidencia.',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('menu_sos')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(alertas.llamadas, 1,
        reason: 'sin GPS la SOS se envia igual, marcada sin ubicacion');
    expect(alertas.sinUbicacionEnviada, isTrue);
  });

  testWidgets('si el envio supera 5 s aparece "Llamar ahora" en el banner',
      (tester) async {
    // Peticion que no responde dentro de la ventana del banner.
    final puerta = Completer<void>();
    final alertas = _AlertasFalsa(puerta: puerta);
    await _mostrar(tester, alertas: alertas);

    await tester.tap(find.byKey(const Key('menu_sos')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Enviando auxilio a central...'), findsOneWidget);
    expect(find.text('Llamar ahora'), findsNothing);

    await tester.pump(const Duration(seconds: 6));

    expect(find.text('Llamar ahora'), findsOneWidget);

    // Cancelar libera la peticion en vuelo sin navegar; asi el test no deja
    // timers reales pendientes.
    await tester.tap(find.text('Cancelar envío'));
    await tester.pump();
    puerta.complete();
    await tester.pump(const Duration(milliseconds: 50));

    expect(alertas.llamadas, 1);
    expect(find.text('ALERTA'), findsOneWidget, reason: 'no navego a rastreo');
    expect(find.text('Cancelar envío'), findsNothing);
  });
}