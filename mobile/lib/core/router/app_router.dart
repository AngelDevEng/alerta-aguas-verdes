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
import '../../features/incidencias/presentation/pages/reportar_incidencia_page.dart';
import '../../features/incidencias/presentation/pages/incidencias_page.dart';
import '../di/injector.dart';
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
/// [ChangeNotifier] traduce un `Stream<AuthState>` en la seÃ±al que
/// `refreshListenable` espera, para que un cambio de sesion reevalÃºe el
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
  static const _rutasProtegidas = <String>{
    Rutas.mapa,
    Rutas.incidencias,
    Rutas.reportar,
  };

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
            builder: (_, _) => const IncidenciasPage(),
          ),
          GoRoute(
            path: 'reportar',
            builder: (_, _) => const ReportarIncidenciaPage(),
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
        // Sin sesiÃ³n: solo se permite el login.
        return enLogin ? null : Rutas.login;
      }
      // Con sesiÃ³n: no quedarse en el login.
      if (enLogin) return Rutas.home;

      if (_rutasProtegidas.contains(destino) && usuario.esCiudadano) {
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
          useMaterial3: true,
        ),
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