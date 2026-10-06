import 'package:alerta_aguas_verdes/core/error/result.dart';
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
Future<void> _mostrar(
  WidgetTester tester, {
  required Usuario usuario,
  List<Unidad> unidades = const [],
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

  testWidgets('tocar SOS muestra el aviso de funcionalidad pendiente',
      (tester) async {
    await _mostrar(tester, usuario: _admin);

    await tester.tap(find.byKey(const Key('menu_sos')));
    await tester.pump();

    expect(
      find.text('El SOS: funcionalidad en preparacion'),
      findsOneWidget,
    );
  });
}
