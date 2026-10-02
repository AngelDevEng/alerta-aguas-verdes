import 'package:alerta_aguas_verdes/core/error/result.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/entities/login_request.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/entities/usuario.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/repositories/auth_repository.dart';
import 'package:alerta_aguas_verdes/features/auth/domain/usecases/auth_usecases.dart';
import 'package:alerta_aguas_verdes/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:alerta_aguas_verdes/features/auth/presentation/bloc/auth_event.dart';
import 'package:alerta_aguas_verdes/features/auth/presentation/bloc/auth_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble de prueba del repositorio.
///
/// Permite verificar la lógica del caso de uso y del BLoC sin levantar HTTP,
/// keychain ni Flutter. Es la razón de poner el contrato en `domain/`.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.usuario, this.falla});

  final Usuario? usuario;
  final Failure? falla;
  int llamadasLogin = 0;
  String? dniRecibido;

  static const _operador = Usuario(
    id: '1',
    dni: '00000001',
    nombreCompleto: 'Operador Prueba',
    rol: 'OPERADOR',
  );

  @override
  Future<AuthSession> login(LoginRequest request) async {
    llamadasLogin++;
    dniRecibido = request.dni;
    if (falla != null) throw falla!;
    return AuthSession(usuario: usuario ?? _operador);
  }

  @override
  Future<Usuario?> restoreSession() async => null;

  @override
  Future<Usuario> me() async => usuario ?? _operador;

  @override
  Future<void> logout(String? refreshToken) async {}
}

void main() {
  group('LoginUseCase', () {
    test('rechaza DNI vacio sin llamar al repositorio', () async {
      final repo = FakeAuthRepository();
      final res = await LoginUseCase(repo)('', 'clave');

      expect(res.isErr, isTrue);
      expect(res.fold((f) => f.message, (_) => ''), 'Ingresa tu DNI');
      expect(repo.llamadasLogin, 0, reason: 'no debe gastar peticion HTTP');
    });

    test('rechaza DNI de menos de 8 digitos', () async {
      final res = await LoginUseCase(FakeAuthRepository())('123', 'clave');
      expect(res.isErr, isTrue);
    });

    test('rechaza contrasena vacia', () async {
      final res = await LoginUseCase(FakeAuthRepository())('00000001', '');
      expect(res.isErr, isTrue);
    });

    test('hace trim al DNI antes de enviarlo', () async {
      final repo = FakeAuthRepository();
      final res = await LoginUseCase(repo)('  00000001 ', 'clave');

      expect(res.isOk, isTrue);
      expect(repo.dniRecibido, '00000001');
    });

    test('propaga el fallo del backend como Err', () async {
      final repo = FakeAuthRepository(
        falla: const AuthFailure('Credenciales invalidas'),
      );
      final res = await LoginUseCase(repo)('00000001', 'mala');

      expect(res.isErr, isTrue);
      expect(res.fold((f) => f.message, (_) => ''), 'Credenciales invalidas');
    });
  });

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emite Loading y luego Autenticado en login exitoso',
      build: () => AuthBloc(
        LoginUseCase(FakeAuthRepository()),
        LogoutUseCase(FakeAuthRepository()),
        RestoreSessionUseCase(FakeAuthRepository()),
        VerifySessionUseCase(FakeAuthRepository()),
      ),
      act: (bloc) => bloc.add(
        const AuthLoginSolicitado(dni: '00000001', password: 'clave'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAutenticado>().having(
          (s) => s.usuario.rol,
          'rol',
          'OPERADOR',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emite NoAutenticado con mensaje si el login falla',
      build: () => AuthBloc(
        LoginUseCase(
          FakeAuthRepository(falla: const AuthFailure('Credenciales invalidas')),
        ),
        LogoutUseCase(FakeAuthRepository()),
        RestoreSessionUseCase(FakeAuthRepository()),
        VerifySessionUseCase(FakeAuthRepository()),
      ),
      act: (bloc) => bloc.add(
        const AuthLoginSolicitado(dni: '00000001', password: 'mala'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthNoAutenticado>().having(
          (s) => s.mensaje,
          'mensaje',
          'Credenciales invalidas',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'sin sesion guardada arranca en NoAutenticado',
      build: () => AuthBloc(
        LoginUseCase(FakeAuthRepository()),
        LogoutUseCase(FakeAuthRepository()),
        RestoreSessionUseCase(FakeAuthRepository()),
        VerifySessionUseCase(FakeAuthRepository()),
      ),
      act: (bloc) => bloc.add(const AuthIniciado()),
      expect: () => [isA<AuthNoAutenticado>()],
    );
  });
}