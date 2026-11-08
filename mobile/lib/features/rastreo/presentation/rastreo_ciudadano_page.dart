import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/storage/token_store.dart';

class RastreoCiudadanoPage extends StatefulWidget {
  const RastreoCiudadanoPage({super.key, required this.alertaId});
  final String alertaId;

  @override
  State<RastreoCiudadanoPage> createState() => _RastreoCiudadanoPageState();
}

class _RastreoCiudadanoPageState extends State<RastreoCiudadanoPage> {
  final TokenStore _store = TokenStore();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://alerta-aguas-verdes-api.onrender.com/api/v1'));
  Timer? _timer;
  String? _unidadId;
  List<dynamic> _puntos = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final token = await _store.readAccess();
      final r = await _dio.get('/alertas/${widget.alertaId}', options: Options(headers: {'Authorization': 'Bearer $token'}));
      final unidadId = r.data['unidadAsignadaId'] as String?;
      if (unidadId != null && unidadId != _unidadId) {
        _unidadId = unidadId;
        final rr = await _dio.get('/unidades/$unidadId/rastro', options: Options(headers: {'Authorization': 'Bearer $token'}));
        setState(() => _puntos = (rr.data as List));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Rastreo')), body: Center(child: Text(_error!)));
    return Scaffold(
      appBar: AppBar(title: const Text('Rastreo ciudadano')),
      body: _puntos.isEmpty
          ? const Center(child: Text('Esperando asignacion de unidad...'))
          : ListView.builder(
              itemCount: _puntos.length,
              itemBuilder: (ctx, i) => ListTile(title: Text('${_puntos[i]['latitud']}, ${_puntos[i]['longitud']}')),
            ),
    );
  }
}
