import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'package:get_it/get_it.dart';

/// Composición raíz.
///
/// Se crea el [AuthBloc] una vez y se comparte entre el router (que necesita
/// leer la sesion para las guardas) y el árbol de widgets. Así no hay dos
/// fuentes de verdad sobre si el usuario está autenticado.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final authBloc = GetIt.I<AuthBloc>()..add(const AuthIniciado());
    return AppRouter(authBloc).build();
  }
}