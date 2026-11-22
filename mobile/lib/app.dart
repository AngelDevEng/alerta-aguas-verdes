import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'features/alertas/presentation/bloc/sos_bloc.dart';
import 'features/alertas/presentation/bloc/sos_event.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';

/// Composición raíz.
///
/// Se crea el [AuthBloc] una vez y se comparte entre el router (que necesita
/// leer la sesion para las guardas) y el árbol de widgets. Así no hay dos
/// fuentes de verdad sobre si el usuario está autenticado.
///
/// Ademas reanuda el SOS pendiente al abrir la app y cada vez que vuelve a
/// primer plano: si el usuario cerro la app con un SOS sin confirmar, el
/// [SosBloc] (singleton) lo reintenta con la misma `Idempotency-Key`.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Despues del primer frame, cuando GetIt ya esta configurado.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reanudarSos());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reanudarSos();
  }

  void _reanudarSos() {
    if (GetIt.I.isRegistered<SosBloc>()) {
      GetIt.I<SosBloc>().add(const SosReanudarPendiente());
    }
    // Aviso best-effort de que la central no responde; no bloquea la app.
    if (GetIt.I.isRegistered<ApiClient>()) {
      GetIt.I<ApiClient>().checkHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = GetIt.I<AuthBloc>()..add(const AuthIniciado());
    return AppRouter(authBloc).build();
  }
}