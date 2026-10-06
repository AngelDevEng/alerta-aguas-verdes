import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/core/location/location_service.dart';
import 'package:alerta_aguas_verdes/features/alertas/domain/repositories/alerta_repository.dart';
import 'package:alerta_aguas_verdes/features/alertas/domain/usecases/alerta_usecases.dart';
import 'package:alerta_aguas_verdes/features/alertas/presentation/bloc/sos_bloc.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/entities/login_request.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/entities/usuario.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/repositories/auth_repository.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/usecases/auth_usecases.dart';
import 'package:alerta_aguas_verdes/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:alerta_aguas_verdes/features/auth/presentation/bloc/auth_event.dart';
import 'package:alerta_aguas_verdes/features/home/presentation/pages/home_page.dart';
import 'package:alerta_aguas_verdes/features/unidades/domain/entities/unidad.dart';
import 'package:alerta_aguas_verdes/features/unidades/domain/repositories/unidad_repository.dart';
import 'package:alerta_aguas_verdes/features/unidades/domain/usecases/unidad_usecases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

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

/// Doble del repositorio de unidades: solo `listar` importa en esta pantalla.
class _UnidadesFalsa implements UnidadRepository {
  _UnidadesFalsa(this.unidades);

  final List<Unidad> unidades;

  @override
  Future<Result<List<Unidad>>> listar() async => Ok(unidades);

  @override
  Future<Result<List<UnidadCercana>>> cercanas({
    required double longitud,
    required double latitud,
    double radioM = UnidadRepository.radioPorDefectoM,
  }) async =>
      const Ok([]);

  @override
  Future<Result<List<Unidad>>> listarDespachables() async => Ok(unidades);
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
  int llamadas = 0;
  double? latitudEnviada;

  @override
  Future<Result<String>> crearSos({
    required double latitud,
    required double longitud,
    double? precisionM,
  }) async {
    llamadas++;
    latitudEnviada = latitud;
    return const Ok('alerta-1');
  }
}

const _sereno = Usuario(
  id: 'u-sereno',
  dni: '00000003',
  nombreCompleto: 'Sereno Prueba',
  rol: 'SERENO',
);

const _admin = Usuario(
  id: 'u-admin',
  dni: '00000002',
  nombreCompleto: 'Admin Prueba',
  rol: 'ADMIN',
);

/// Arma la pantalla con la sesion ya activa y las unidades dadas.
///
/// Los doubles del SOS son opcionales: si no se pasan, se usa un GPS y un
/// backend sanos para que cualquier test que solo verifique el menu no tenga
/// que pensar en el flujo.
Future<void> _mostrar(
  WidgetTester tester, {
  required Usuario usuario,
  List<Unidad> unidades = const [],
  LocationService? location,
  AlertaRepository? alertas,
}) async {
  final auth = _AuthFalso(usuario);
  GetIt.I.registerLazySingleton<AuthBloc>(
    () => AuthBloc(
      LoginUseCase(auth),
      LogoutUseCase(auth),
      RestoreSessionUseCase(auth),
      VerifySessionUseCase(auth),
      LoginPorPlacaUseCase(auth),
    ),
  );
  GetIt.I.registerFactory<ListarUnidadesUseCase>(
    () => ListarUnidadesUseCase(_UnidadesFalsa(unidades)),
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
  );
  GetIt.I.registerFactory<SosBloc>(() => sos);

  await tester.pumpWidget(const MaterialApp(home: HomePage()));
  GetIt.I<AuthBloc>().add(const AuthIniciado());
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() async {
    await GetIt.I.reset();
  });

  testWidgets('rol distinto de sereno ve SOS y Emergencia, sin patrulla',
      (tester) async {
    await _mostrar(tester, usuario: _admin);

    expect(find.text('Menú Principal'), findsOneWidget);
    expect(find.byKey(const Key('menu_sos')), findsOneWidget);
    expect(find.byKey(const Key('menu_emergencia')), findsOneWidget);
    expect(find.byKey(const Key('menu_reportar')), findsOneWidget);
    expect(find.byKey(const Key('menu_mapa_calor')), findsOneWidget);
    expect(find.byKey(const Key('menu_placa')), findsNothing);
    expect(find.byKey(const Key('menu_rastreo')), findsNothing);
  });

  testWidgets('sereno con unidad ve el panel de patrulla y rastreo',
      (tester) async {
    await _mostrar(
      tester,
      usuario: _sereno,
      unidades: [
        Unidad(
          id: 'unidad-1',
          codigo: 'SER-01',
          tipo: TipoUnidad.patrulla,
          estado: EstadoUnidad.disponible,
          placa: 'EGA-123',
          responsableId: _sereno.id,
        ),
      ],
    );

    expect(find.text('Panel Patrulla: EGA-123'), findsOneWidget);
    expect(find.byKey(const Key('menu_placa')), findsOneWidget);
    expect(find.byKey(const Key('menu_rastreo')), findsOneWidget);
    expect(find.byKey(const Key('menu_sos')), findsNothing);
    expect(find.byKey(const Key('menu_emergencia')), findsNothing);
    expect(find.byKey(const Key('menu_reportar')), findsOneWidget);
  });

  testWidgets('sereno sin unidad asignada muestra "Panel Patrulla" sin placa',
      (tester) async {
    await _mostrar(tester, usuario: _sereno, unidades: const []);

    expect(find.text('Panel Patrulla'), findsOneWidget);
    expect(find.text('Panel Patrulla: EGA-123'), findsNothing);
  });

  testWidgets('tocar SOS envia la alerta y confirma con el texto del legacy',
      (tester) async {
    final alertas = _AlertasFalsa();
    await _mostrar(tester, usuario: _admin, alertas: alertas);

    await tester.tap(find.byKey(const Key('menu_sos')));
    await tester.pumpAndSettle();

    expect(alertas.llamadas, 1);
    expect(alertas.latitudEnviada, isNotNull);
    expect(find.text('Auxilio enviado a central'), findsOneWidget);
  });

  testWidgets('si el GPS falla, el SOS avisa y no llega al backend',
      (tester) async {
    final alertas = _AlertasFalsa();
    await _mostrar(
      tester,
      usuario: _admin,
      alertas: alertas,
      location: _LocationFake(
        falla: const LocalFailure(
          'El GPS esta apagado. Activalo para ubicar la incidencia.',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('menu_sos')));
    await tester.pumpAndSettle();

    expect(alertas.llamadas, 0, reason: 'sin GPS no se gasta el POST');
    expect(
      find.text('El GPS esta apagado. Activalo para ubicar la incidencia.'),
      findsOneWidget,
    );
  });
}
