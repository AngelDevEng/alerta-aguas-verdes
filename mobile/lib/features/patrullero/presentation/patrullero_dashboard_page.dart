import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injector.dart';
import '../../../core/error/result.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/storage/token_store.dart';
import '../../alertas/domain/usecases/alerta_usecases.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_event.dart';

class PatrulleroDashboardPage extends StatefulWidget {
  const PatrulleroDashboardPage({super.key});
  @override
  State<PatrulleroDashboardPage> createState() => _PatrulleroDashboardPageState();
}

class _PatrulleroDashboardPageState extends State<PatrulleroDashboardPage> {
  final TokenStore _store = TokenStore();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://alerta-aguas-verdes-api.onrender.com/api/v1'));
  late final SocketService _socket;
  StreamSubscription? _alertaSub;
  List<Map<String, dynamic>> _alertas = [];
  String? _error;
  bool _accionando = false;

  @override
  void initState() {
    super.initState();
    _socket = sl<SocketService>();
    _initSocket();
    _cargar();
  }

  Future<void> _initSocket() async {
    final token = await _store.readAccess();
    if (token == null || token.isEmpty) return;
    _socket = SocketService(baseUrl: 'https://alerta-aguas-verdes-api.onrender.com/ws', token: token);
    _socket.connect();
    _alertaSub = _socket.alertas.listen((alerta) {
      setState(() => _alertas.insert(0, alerta));
    });
  }

  Future<void> _cargar() async {
    try {
      final token = await _store.readAccess();
      if (token == null || token.isEmpty) {
        setState(() => _error = 'Inicia sesion como operador/sereno para ver alertas.');
        return;
      }
      final r = await _dio.get('/alertas/activas', options: Options(headers: {'Authorization': 'Bearer $token'}));
      setState(() {
        _alertas = (r.data as List).cast<Map<String, dynamic>>();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _cambiarEstado(String id, String estado) async {
    setState(() => _accionando = true);
    final caso = sl<CambiarEstadoAlertaUseCase>();
    final r = await caso(id, estado);
    if (!mounted) return;
    setState(() => _accionando = false);
    if (r case Err(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Alerta $estado')),
    );
    _cargar();
  }

  @override
  void dispose() {
    _alertaSub?.cancel();
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Alertas activas')), body: Center(child: Text(_error!)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas activas (tiempo real)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') {
                context.read<AuthBloc>().add(const AuthLogoutSolicitado());
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Cerrar sesion')),
            ],
          ),
        ],
      ),
      body: _alertas.isEmpty
          ? const Center(child: Text('No hay alertas activas.'))
          : ListView.builder(
              itemCount: _alertas.length,
              itemBuilder: (ctx, i) {
                final a = _alertas[i];
                final id = a['id']?.toString() ?? '';
                final estado = a['estado']?.toString() ?? 'ACTIVA';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(a['direccion']?.toString() ?? id),
                    subtitle: Text('Estado: $estado'),
                    trailing: estado == 'ACTIVA' && !_accionando
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () => _cambiarEstado(id, 'ACEPTADA'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _cambiarEstado(id, 'CANCELADA'),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}