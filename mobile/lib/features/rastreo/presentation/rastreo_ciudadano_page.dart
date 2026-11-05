import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class RastreoCiudadanoPage extends StatefulWidget {
  const RastreoCiudadanoPage({super.key, required this.unidadId});
  final String unidadId;

  @override
  State<RastreoCiudadanoPage> createState() => _RastreoCiudadanoPageState();
}

class _RastreoCiudadanoPageState extends State<RastreoCiudadanoPage> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://alerta-aguas-verdes-api.onrender.com/api/v1'));
  List<dynamic> _puntos = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await _dio.get('/unidades/${widget.unidadId}/rastro');
      setState(() => _puntos = (r.data as List));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Rastreo')), body: Center(child: Text(_error!)));
    return Scaffold(
      appBar: AppBar(title: const Text('Rastreo ciudadano')),
      body: ListView.builder(
        itemCount: _puntos.length,
        itemBuilder: (ctx, i) => ListTile(title: Text('${_puntos[i]['latitud']}, ${_puntos[i]['longitud']}')),
      ),
    );
  }
}
