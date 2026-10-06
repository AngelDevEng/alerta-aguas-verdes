import '../../../../core/error/result.dart';
import '../../../../core/storage/token_store.dart';
import '../../domain/entities/login_request.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_dto.dart';

/// Fuente local de la sesion (keychain cifrado).
///
/// Aislar el almacenamiento permite que el repositorio decida cuando persistir,
/// que es una politica y no un detalle de HTTP.
abstract interface class AuthLocalDataSource {
  Future<void> persist(AuthSessionDtoLike session);
  Future<Usuario?> cachedUser();
  Future<String?> refreshToken();
  Future<void> clear();
}

/// Copia minima del DTO que el repositorio necesita persistir.
/// Evita que `data/` exponga el modelo completo al contrato de dominio.
class AuthSessionDtoLike {
  const AuthSessionDtoLike({
    required this.accessToken,
    required this.refreshToken,
    required this.usuario,
  });

  final String accessToken;
  final String refreshToken;
  final Usuario usuario;
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._tokens);

  final TokenStore _tokens;
  Usuario? _userCache;

  @override
  Future<void> persist(AuthSessionDtoLike session) async {
    await _tokens.save(
      access: session.accessToken,
      refresh: session.refreshToken,
    );
    _userCache = session.usuario;
  }

  @override
  Future<Usuario?> cachedUser() async => _userCache;

  @override
  Future<String?> refreshToken() => _tokens.readRefresh();

  @override
  Future<void> clear() async {
    await _tokens.clear();
    _userCache = null;
  }
}

/// Implementacion del contrato de dominio `AuthRepository`.
///
/// Coordina red + almacenamiento local. El BLoC solo conoce la interfaz.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local);

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  @override
  Future<AuthSession> login(LoginRequest request) =>
      _ingresar(() => _remote.login(dni: request.dni, password: request.password));

  @override
  Future<AuthSession> loginPorPlaca(LoginPlacaRequest request) =>
      _ingresar(() => _remote.loginPorPlaca(placa: request.placa, password: request.password));

  Future<AuthSession> _ingresar(Future<Result<AuthSessionDto>> Function() llamada) async {
    final res = await llamada();
    final dto = res.valueOrThrow; // Err lanza Failure: el caso de uso la captura
    await _local.persist(
      AuthSessionDtoLike(
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
        usuario: dto.usuario.toEntity(),
      ),
    );
    return dto.toEntity();
  }

  @override
  Future<Usuario?> restoreSession() => _local.cachedUser();

  @override
  Future<Usuario> me() async {
    final res = await _remote.me();
    return res.valueOrThrow.toEntity();
  }

  @override
  Future<void> logout(String? refreshToken) async {
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _remote.logout(refreshToken);
      }
    } finally {
      // Un backend caido no debe dejar tokens validos en el dispositivo.
      await _local.clear();
    }
  }
}