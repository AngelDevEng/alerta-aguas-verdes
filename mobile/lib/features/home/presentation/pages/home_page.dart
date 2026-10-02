import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

/// Home: menu de accesos.
///
/// La lista de acciones se filtra por rol en el cliente para no mostrar botones
/// que el backend responderia con 403. El backend sigue siendo la autoridad.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      bloc: GetIt.I<AuthBloc>(),
      builder: (context, state) {
        final usuario = state is AuthAutenticado ? state.usuario : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Alerta Aguas Verdes'),
            actions: [
              IconButton(
                tooltip: 'Cerrar sesion',
                icon: const Icon(Icons.logout),
                onPressed: () => GetIt.I<AuthBloc>().add(const AuthLogoutSolicitado()),
              ),
            ],
          ),
          body: usuario == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Saludo(nombre: usuario.nombreCompleto, rol: usuario.rol),
                    const SizedBox(height: 16),
                    if (usuario.esOperador) ...[
                      _Accion(
                        icono: Icons.map_outlined,
                        titulo: 'Mapa operativo',
                        detalle: 'Unidades y rastros en vivo',
                        onTap: () => context.go(Rutas.mapa),
                      ),
                      _Accion(
                        icono: Icons.list_alt_outlined,
                        titulo: 'Incidencias',
                        detalle: 'Reportes, despacho y estados',
                        onTap: () => context.go(Rutas.incidencias),
                      ),
                    ],
                    _Accion(
                      icono: Icons.add_location_alt_outlined,
                      titulo: 'Reportar incidencia',
                      detalle: 'Describe y ubica el evento',
                      onTap: () => context.go(Rutas.reportar),
                    ),
                    _Accion(
                      icono: Icons.emergency_outlined,
                      titulo: 'Central de emergencias',
                      detalle: 'Telefonos de PNP, bomberos y municipalidad',
                      onTap: () => context.go(Rutas.emergencias),
                      destacado: true,
                    ),
                    const SizedBox(height: 24),
                    _Accion(
                      icono: Icons.person_outline,
                      titulo: 'Perfil',
                      detalle: 'Datos de cuenta y ajustes',
                      onTap: () => context.go(Rutas.perfil),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _Saludo extends StatelessWidget {
  const _Saludo({required this.nombre, required this.rol});

  final String nombre;
  final String rol;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Perfil: $rol'),
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.destacado = false,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: destacado ? scheme.errorContainer : null,
      child: ListTile(
        leading: Icon(icono, color: destacado ? scheme.onErrorContainer : null),
        title: Text(titulo),
        subtitle: Text(detalle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}