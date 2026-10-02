import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/usuario.dart';
import '../models/auth_dto.dart';

/// Fuente de datos remota de autenticacion.
///
/// Solo habla HTTP y devuelve [Result]: no conoce BLoC, almacenamiento local ni
/// el contrato de dominio. Por eso `AuthRepositoryImpl` se puede probar con un
/// `ApiClient` falso.
abstract interface class AuthRemoteDataSource {
  Future<Result<AuthSessionDto>> login({
    required String dni,
    required String password,
  });

  Future<Result<AuthSessionDto>> refresh(String refreshToken);

  Future<Result<void>> logout(String refreshToken);

  Future<Result<UsuarioDto>> me();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  static Map<String, dynamic> _asMap(dynamic data) =>
      Map<String, dynamic>.from(data as Map);

  @override
  Future<Result<AuthSessionDto>> login({
    required String dni,
    required String password,
  }) =>
      _api.post<AuthSessionDto>(
        '/auth/login',
        body: {'dni': dni, 'password': password},
        parse: (data) => AuthSessionDto.fromJson(_asMap(data)),
      );

  @override
  Future<Result<AuthSessionDto>> refresh(String refreshToken) =>
      _api.post<AuthSessionDto>(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
        parse: (data) => AuthSessionDto.fromJson(_asMap(data)),
      );

  @override
  Future<Result<void>> logout(String refreshToken) => _api.post<void>(
        '/auth/logout',
        body: {'refreshToken': refreshToken},
        parse: (_) {},
      );

  @override
  Future<Result<UsuarioDto>> me() => _api.get<UsuarioDto>(
        '/auth/me',
        parse: (data) => UsuarioDto.fromJson(_asMap(data)),
      );
}

/// Traduce DTO -> entidad de dominio.
extension AuthSessionDtoX on AuthSessionDto {
  AuthSession toEntity() => AuthSession(usuario: usuario.toEntity());
}

extension UsuarioDtoX on UsuarioDto {
  Usuario toEntity() => Usuario(
        id: id,
        dni: dni,
        nombreCompleto: nombreCompleto,
        rol: rol,
        email: email,
      );
}