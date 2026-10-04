import 'package:get_it/get_it.dart';

import '../location/location_service.dart';
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
import '../../features/incidencias/data/datasources/incidencia_remote_datasource.dart';
import '../../features/incidencias/data/repositories/incidencia_repository_impl.dart';
import '../../features/incidencias/domain/repositories/incidencia_repository.dart';
import '../../features/incidencias/domain/usecases/incidencia_usecases.dart';
import '../../features/incidencias/presentation/bloc/incidencias_bloc.dart';
import '../../features/incidencias/presentation/bloc/incidencia_detalle_bloc.dart';
import '../../features/incidencias/presentation/bloc/reportar_bloc.dart';
import '../../features/unidades/data/datasources/unidad_remote_datasource.dart';
import '../../features/unidades/data/repositories/unidad_repository_impl.dart';
import '../../features/unidades/domain/repositories/unidad_repository.dart';
import '../../features/unidades/domain/usecases/unidad_usecases.dart';

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

  // --- incidencias ---
  sl.registerLazySingleton<IncidenciaRemoteDataSource>(
    () => IncidenciaRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<IncidenciaRepository>(
    () => IncidenciaRepositoryImpl(sl<IncidenciaRemoteDataSource>()),
  );
  sl.registerFactory(
    () => ListarIncidenciasUseCase(sl<IncidenciaRepository>()),
  );
  sl.registerFactory(
    () => ObtenerDetalleIncidenciaUseCase(sl<IncidenciaRepository>()),
  );
  sl.registerFactory(
    () => CambiarEstadoIncidenciaUseCase(sl<IncidenciaRepository>()),
  );
  sl.registerFactory(
    () => AsignarUnidadUseCase(sl<IncidenciaRepository>()),
  );
  // Factory, no singleton: cada apertura de la pantalla arranca con la pagina 1
  // y sin datos viejos de una visita anterior.
  sl.registerFactory(
    () => IncidenciasBloc(
      sl<ListarIncidenciasUseCase>(),
      sl<IncidenciaRepository>(),
    ),
  );
  sl.registerFactory(
    () => ReportarIncidenciaUseCase(sl<IncidenciaRepository>()),
  );
  sl.registerFactory(
    () => SubirEvidenciaUseCase(sl<IncidenciaRepository>()),
  );
  sl.registerFactory(
    () => ReportarBloc(
      sl<ReportarIncidenciaUseCase>(),
      sl<SubirEvidenciaUseCase>(),
    ),
  );

  // El detalle recibe el id por constructor: el router lo resuelve desde los
  // parametros de la ruta, asi que el factory toma el id como argumento en vez
  // de cerrarlo.
  sl.registerFactoryParam<IncidenciaDetalleBloc, String, void>(
    (id, _) => IncidenciaDetalleBloc(
      sl<ObtenerDetalleIncidenciaUseCase>(),
      sl<CambiarEstadoIncidenciaUseCase>(),
      sl<AsignarUnidadUseCase>(),
      id,
    ),
  );

  // --- unidades ---
  sl.registerLazySingleton<UnidadRemoteDataSource>(
    () => UnidadRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<UnidadRepository>(
    () => UnidadRepositoryImpl(sl<UnidadRemoteDataSource>()),
  );
  sl.registerFactory(
    () => ListarUnidadesDespachablesUseCase(sl<UnidadRepository>()),
  );
  sl.registerFactory(
    () => ListarUnidadesCercanasUseCase(sl<UnidadRepository>()),
  );

  // --- ubicacion ---
  // Sin estado: el permiso se resuelve en cada llamada, no se cachea para que
  // el usuario pueda revocar el permiso desde Ajustes y el proximo reporte lo
  // respete sin reiniciar la app.
  sl.registerFactory(() => const LocationService());
}