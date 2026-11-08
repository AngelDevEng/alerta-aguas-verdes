import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/storage/token_store.dart';

class PatrulleroDashboardPage extends StatefulWidget {
  const PatrulleroDashboardPage({super.key});
  @override
  State<PatrulleroDashboardPage> createState() => _PatrulleroDashboardPageState();
}

class _PatrulleroDashboardPageState extends State<PatrulleroDashboardPage> {
  final TokenStore _store = TokenStore();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://alerta-aguas-verdes-api.onrender.com/api/v1'));
  List<dynamic> _alertas = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final token = await _store.readAccess();
      final r = await _dio.get('/alertas/activas', options: Options(headers: {'Authorization': 'Bearer $token'}));
      setState(() => _alertas = (r.data as List));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Alertas activas')), body: Center(child: Text(_error!)));
    return Scaffold(
      appBar: AppBar(title: const Text('Alertas activas'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)]),
      body: ListView.builder(
        itemCount: _alertas.length,
        itemBuilder: (ctx, i) {
          final a = _alertas[i] as Map;
          return ListTile(
            title: Text(a['direccion']?.toString() ?? a['id'].toString()),
            subtitle: Text('Estado: ${a['estado']}'),
          );
        },
      ),
    );
  }
}
