import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Pantalla de login.
///
/// Cumple el rol de *View* en MVVM: no valida reglas de negocio (eso vive en
/// [LoginUseCase]) ni habla con el backend. Solo despacha eventos y dibuja el
/// estado que devuelve el BLoC.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _dniCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _ocultarPass = true;

  @override
  void dispose() {
    _dniCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _enviar() {
    FocusScope.of(context).unfocus();
    GetIt.I<AuthBloc>().add(
          AuthLoginSolicitado(
            dni: _dniCtrl.text,
            password: _passCtrl.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          bloc: GetIt.I<AuthBloc>(),
          builder: (context, state) {
            final cargando = state is AuthLoading;
            final error = state is AuthNoAutenticado ? state.mensaje : null;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_moon_outlined, size: 72),
                      const SizedBox(height: 12),
                      Text(
                        'Alerta Aguas Verdes',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Municipalidad de Aguas Verdes',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _dniCtrl,
                        enabled: !cargando,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: const InputDecoration(
                          labelText: 'DNI',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        enabled: !cargando,
                        obscureText: _ocultarPass,
                        decoration: InputDecoration(
                          labelText: 'Contrasena',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_ocultarPass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _ocultarPass = !_ocultarPass),
                          ),
                        ),
                        onFieldSubmitted: (_) => _enviar(),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(mensaje: error),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: cargando ? null : _enviar,
                          child: cargando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Ingresar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}