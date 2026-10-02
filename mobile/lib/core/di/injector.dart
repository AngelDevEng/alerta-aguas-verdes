import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../network/auth_interceptor.dart';
import '../storage/token_store.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/catalogos/data/datasources/catalogo_remote_datasource.dart';
import '../../features/catalogos/data/repositories/catalogo_repository_impl.dart';
import '../../features/catalogos/domain/repositories/catalogo_repository.dart';
import '../../features/catalogos/domain/usecases/catalogo_usecases.dart';
import '../../features/catalogos/presentation/bloc/catalogos_bloc.dart';

final sl = GetIt.instance;

/// URLs por entorno.
///
/// `--dart-define=API_BASE_URL=...` permite apuntar a Render, a un staging o al
/// emulador sin recompilar codigo.
class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1', // localhost desde emulador Android
  );
}

Future<void> configureDependencies() async {
  // --- core ---
  sl.registerLazySingleton<TokenStore>(TokenStore.new);

  final tokens = sl<TokenStore>();
  final api = ApiClient(baseUrl: Env.apiBaseUrl);
  api.dio.interceptors.addAll([
    AuthInterceptor(tokens: tokens),
    RefreshInterceptor(tokens: tokens, dio: api.dio),
  ]);
  sl.registerLazySingleton<ApiClient>(() => api);

  // --- data ---
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sl<TokenStore>()),
  );

  // --- domain ---
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      sl<AuthRemoteDataSource>(),
      sl<AuthLocalDataSource>(),
    ),
  );

  // --- usecases ---
  sl.registerFactory(() => LoginUseCase(sl<AuthRepository>()));
  sl.registerFactory(() => LogoutUseCase(sl<AuthRepository>()));
  sl.registerFactory(() => RestoreSessionUseCase(sl<AuthRepository>()));
  sl.registerFactory(() => VerifySessionUseCase(sl<AuthRepository>()));

  // --- presentation ---
  // Singleton: el estado de sesion es de toda la app y lo consultan el router
  // (para las guardas) y varias pantallas. Con factory, dos llamadas a
  // GetIt.I<AuthBloc>() pueden obtener instancias distintas y las guardas
  // decidirian distinto que la UI.
  sl.registerLazySingleton(
    () => AuthBloc(
      sl<LoginUseCase>(),
      sl<LogoutUseCase>(),
      sl<RestoreSessionUseCase>(),
      sl<VerifySessionUseCase>(),
    ),
  );

  // --- catalogos ---
  sl.registerLazySingleton<CatalogoRemoteDataSource>(
    () => CatalogoRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<CatalogoRepository>(
    () => CatalogoRepositoryImpl(sl<CatalogoRemoteDataSource>()),
  );
  sl.registerFactory(
    () => ObtenerEmergenciasUseCase(sl<CatalogoRepository>()),
  );
  sl.registerFactory(
    () => ObtenerEmergenciasWhatsappUseCase(sl<CatalogoRepository>()),
  );
  sl.registerFactory(
    () => ObtenerAsociacionesUseCase(sl<CatalogoRepository>()),
  );
  sl.registerFactory(
    () => CatalogosBloc(sl<ObtenerEmergenciasUseCase>()),
  );
}