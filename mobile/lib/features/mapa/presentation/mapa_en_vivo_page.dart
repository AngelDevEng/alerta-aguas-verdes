import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/realtime/socket_service.dart';

class MapaEnVivoPage extends StatefulWidget {
  const MapaEnVivoPage({super.key, required this.socketService});
  final SocketService socketService;

  @override
  State<MapaEnVivoPage> createState() => _MapaEnVivoPageState();
}

class _MapaEnVivoPageState extends State<MapaEnVivoPage> {
  final Map<String, LatLng> _positions = {};

  @override
  void initState() {
    super.initState();
    widget.socketService.positions.listen((data) {
      final id = data['unidadId']?.toString();
      final lat = (data['latitud'] as num?)?.toDouble();
      final lon = (data['longitud'] as num?)?.toDouble();
      if (id != null && lat != null && lon != null) {
        setState(() => _positions[id] = LatLng(lat, lon));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa en vivo')),
      body: FlutterMap(
        options: const MapOptions(initialCenter: LatLng(-3.5, -80.3), initialZoom: 13),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
          MarkerLayer(
            markers: _positions.entries
                .map((e) => Marker(
                      point: e.value,
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.directions_car, color: Colors.blue),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
