import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/di/injector.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/storage/token_store.dart';

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
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: _alertas.isEmpty
          ? const Center(child: Text('No hay alertas activas.'))
          : ListView.builder(
              itemCount: _alertas.length,
              itemBuilder: (ctx, i) {
                final a = _alertas[i];
                return ListTile(
                  title: Text(a['direccion']?.toString() ?? a['id']?.toString() ?? 'Alerta'),
                  subtitle: Text('Estado: ${a['estado'] ?? 'ACTIVA'}'),
                  trailing: const Icon(Icons.warning, color: Colors.red),
                );
              },
            ),
    );
  }
}