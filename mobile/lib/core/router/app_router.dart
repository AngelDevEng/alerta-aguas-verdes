import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/usuario.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/catalogos/presentation/bloc/catalogos_bloc.dart';
import '../../features/catalogos/presentation/bloc/catalogos_event.dart';
import '../../features/catalogos/presentation/pages/emergencias_page.dart';
import '../../features/incidencias/presentation/bloc/incidencias_bloc.dart';
import '../../features/incidencias/presentation/bloc/incidencias_event.dart';
import '../../features/incidencias/presentation/bloc/incidencia_detalle_bloc.dart';
import '../../features/incidencias/presentation/bloc/incidencia_detalle_event.dart';
import '../../features/incidencias/presentation/bloc/reportar_bloc.dart';
import '../../features/incidencias/presentation/pages/incidencias_page.dart';
import '../../features/incidencias/presentation/pages/incidencia_detalle_page.dart';
import '../../features/incidencias/presentation/pages/reportar_incidencia_page.dart';
import '../di/injector.dart';
import '../theme/app_theme.dart';
import 'not_found_page.dart';

/// Rutas de la app. Nombres centralizados para no repetir strings.
class Rutas {
  static const login = '/login';
  static const home = '/';
  static const mapa = '/mapa';
  static const reportar = '/reportar';
  static const incidencias = '/incidencias';
  static const emergencias = '/emergencias';
  static const perfil = '/perfil';
}

/// Puente BLoC -> GoRouter.
///
/// GoRouter no conoce BLoC, y BLoC no debe conocer el router. Este
/// [ChangeNotifier] traduce un `Stream<AuthState>` en la señal que
/// `refreshListenable` espera, para que un cambio de sesion reevalúe el
/// `redirect` sin reconstruir la app.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(AuthBloc bloc) {
    _sub = bloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Configura el router con guardas por rol, equivalentes a `JwtAuthGuard` +
/// `RolesGuard` de NestJS.
class AppRouter {
  AppRouter(this._authBloc);

  final AuthBloc _authBloc;

  /// Rutas que exigen rol de operador (SERENO/OPERADOR/ADMIN/DIRECTIVO).
  /// El backend igual valida con `@Roles`; esto solo evita mostrar una pantalla
  /// que el servidor iba a rechazar con 403.
  ///
  /// `Rutas.reportar` NO esta aca a proposito: `POST /incidencias` acepta
  /// `CIUDADANO` en el backend, y Reportar es justamente la pantalla que mas le
  /// importa a un vecino. Bloquearla seria quitarle la funcion principal de la
  /// app a la mitad de los usuarios.
  static const _rutasProtegidas = <String>{
    Rutas.mapa,
    Rutas.incidencias,
  };

  /// Si la ruta cae dentro de una zona que exige rol operativo.
  ///
  /// Compara por prefijo y no por igualdad exacta porque hay rutas con
  /// parametros (`/incidencias/:id`). Con `contains` sobre `matchedLocation`, el
  /// detalle de una incidencia se escapaba de la guarda y un ciudadano llegaba
  /// hasta la pantalla para recibir un 403 del servidor. La guarda del cliente
  /// no reemplaza a la del backend: solo evita mostrar una pantalla que el
  /// servidor va a rechazar.
  static bool _exigeOperador(String ruta) => _rutasProtegidas
      .any((r) => ruta == r || ruta.startsWith('$r/'));

  late final GoRouter _router = GoRouter(
    initialLocation: Rutas.home,
    refreshListenable: _AuthRefresh(_authBloc),
    routes: [
      GoRoute(path: Rutas.login, builder: (_, _) => const LoginPage()),
      GoRoute(
        path: Rutas.home,
        builder: (_, _) => const HomePage(),
        routes: [
          GoRoute(
            path: 'mapa',
            builder: (_, _) => const _MapaPage(),
          ),
          GoRoute(
            path: 'incidencias',
            // Igual que en emergencias: el Bloc nace en la ruta y dispara la
            // carga inicial. Dejarlo al usuario abriria la pantalla en
            // IncidenciasInicial para siempre.
            builder: (_, _) => BlocProvider<IncidenciasBloc>(
              create: (_) => sl<IncidenciasBloc>()..add(const CargarIncidencias()),
              child: const IncidenciasPage(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                // El id viaja por la ruta, no por un evento: asi el bloc queda
                // atado a una sola incidencia y una recarga no puede cambiarle
                // el sujeto al operador. `registerFactoryParam` lo recibe por
                // constructor.
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return BlocProvider<IncidenciaDetalleBloc>(
                    create: (_) => sl<IncidenciaDetalleBloc>(param1: id)
                      ..add(const DetalleSolicitado()),
                    child: const IncidenciaDetallePage(),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'reportar',
            // Al volver, `pop(true)` le avisa a la pantalla anterior que hay una
            // incidencia nueva, para que la lista se recargue.
            builder: (_, _) => BlocProvider<ReportarBloc>(
              create: (_) => sl<ReportarBloc>(),
              child: const ReportarIncidenciaPage(),
            ),
          ),
          GoRoute(
            path: 'emergencias',
            // El Bloc se crea con alcance de la ruta y dispara la carga
            // inicial: si se dejara al usuario, la pantalla abriria en
            // CatalogosCargando para siempre.
            builder: (_, _) => BlocProvider<CatalogosBloc>(
              create: (_) => sl<CatalogosBloc>()..add(const CargarEmergencias()),
              child: const EmergenciasPage(),
            ),
          ),
          GoRoute(
            path: 'perfil',
            builder: (_, _) => const _PerfilPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => const NotFoundPage(),
    redirect: (context, state) {
      final usuario = _usuarioActual;
      final destino = state.matchedLocation;
      final enLogin = destino == Rutas.login;

      if (usuario == null) {
        // Sin sesión: solo se permite el login.
        return enLogin ? null : Rutas.login;
      }
      // Con sesión: no quedarse en el login.
      if (enLogin) return Rutas.home;

      if (_exigeOperador(destino) && usuario.esCiudadano) {
        return Rutas.home;
      }
      return null;
    },
  );

  Usuario? get _usuarioActual => switch (_authBloc.state) {
        AuthAutenticado(:final usuario) => usuario,
        _ => null,
      };

  Widget build() => MaterialApp.router(
        title: 'Alerta Aguas Verdes',
        debugShowCheckedModeBanner: false,
        // El tema vive en `core/theme`: la paleta del legacy esta ahi y no
        // dispersa en cada widget.
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: _router,
      );
}

/// Placeholder del mapa con `flutter_map` + tiles de OSM.
/// Se implementa en la feature `mapa`.
class _MapaPage extends StatelessWidget {
  const _MapaPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Mapa operativo')),
    );
  }
}

class _PerfilPage extends StatelessWidget {
  const _PerfilPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Perfil y ajustes')),
    );
  }
}