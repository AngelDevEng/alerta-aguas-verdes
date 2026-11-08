import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../../../core/storage/token_store.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TokenStore _store = TokenStore();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://alerta-aguas-verdes-api.onrender.com/api/v1'));
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final token = await _store.readAccess();
      final r = await _dio.get('/incidencias/estadisticas', options: Options(headers: {'Authorization': 'Bearer $token'}));
      setState(() => _data = (r.data as Map).cast<String, dynamic>());
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Indicadores')), body: Center(child: Text(_error!)));
    if (_data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Indicadores')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(const JsonEncoder.withIndent('  ').convert(_data)),
      ),
    );
  }
}
