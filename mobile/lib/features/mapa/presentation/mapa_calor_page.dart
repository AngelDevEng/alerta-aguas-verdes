import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/storage/token_store.dart';

class MapaCalorPage extends StatefulWidget {
  const MapaCalorPage({super.key});
  @override
  State<MapaCalorPage> createState() => _MapaCalorPageState();
}

class _MapaCalorPageState extends State<MapaCalorPage> {
  final TokenStore _store = TokenStore();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://alerta-aguas-verdes-api.onrender.com/api/v1'));
  List<dynamic> _zonas = [];
  final _desde = TextEditingController();
  final _hasta = TextEditingController();
  final _tipo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final token = await _store.readAccess();
      final params = <String, dynamic>{};
      if (_desde.text.isNotEmpty) params['desde'] = _desde.text;
      if (_hasta.text.isNotEmpty) params['hasta'] = _hasta.text;
      if (_tipo.text.isNotEmpty) params['tipo'] = _tipo.text;
      final r = await _dio.get('/incidencias/zonas-calor', queryParameters: params, options: Options(headers: {'Authorization': 'Bearer $token'}));
      setState(() => _zonas = (r.data as List));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de calor')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _desde, decoration: const InputDecoration(labelText: 'Desde (ISO)'))),
                Expanded(child: TextField(controller: _hasta, decoration: const InputDecoration(labelText: 'Hasta (ISO)'))),
                Expanded(child: TextField(controller: _tipo, decoration: const InputDecoration(labelText: 'Tipo'))),
                ElevatedButton(onPressed: _cargar, child: const Text('Aplicar')),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: const MapOptions(initialCenter: LatLng(-3.5, -80.3), initialZoom: 13),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                MarkerLayer(
                  markers: _zonas.map((z) => Marker(
                    point: LatLng((z['lat'] as num).toDouble(), (z['lng'] as num).toDouble()),
                    width: 20, height: 20,
                    child: Container(color: Colors.red.withValues(alpha: 0.5)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
