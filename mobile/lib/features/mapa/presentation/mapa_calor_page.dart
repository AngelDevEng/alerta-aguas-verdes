import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapaCalorPage extends StatelessWidget {
  const MapaCalorPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de calor')),
      body: FlutterMap(
        options: const MapOptions(initialCenter: LatLng(-3.5, -80.3), initialZoom: 13),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
        ],
      ),
    );
  }
}
