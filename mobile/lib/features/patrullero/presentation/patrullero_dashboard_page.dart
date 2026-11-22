import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/di/injector.dart';
import '../../../core/error/result.dart';
import '../../../core/maps/map_tiles.dart';
import '../../../core/network/api_client.dart';
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
  Dio get _dio => sl<ApiClient>().dio;
  SocketService? _socket;
  StreamSubscription? _alertaSub;
  List<Map<String, dynamic>> _alertas = [];
  String? _error;
  bool _accionando = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _initSocket();
    _cargar();
  }

  Future<void> _initSocket() async {
    final token = await _store.readAccess();
    if (token == null || token.isEmpty) return;
    final base = sl<ApiClient>().dio.options.baseUrl.replaceAll('/api/v1', '/ws');
    final socket = SocketService(baseUrl: base, token: token);
    socket.connect();
    _socket = socket;
    _alertaSub = socket.alertas.listen((_) => _cargar());
  }

  Future<void> _cargar() async {
    try {
      final token = await _store.readAccess();
      if (token == null || token.isEmpty) {
        setState(() {
          _error = 'Inicia sesion para ver alertas.';
          _cargando = false;
        });
        return;
      }
      final r = await _dio.get<dynamic>(
        '/alertas/activas',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = r.data;
      setState(() {
        _alertas = data is List ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudieron cargar las alertas.';
        _cargando = false;
      });
    }
  }

  Future<void> _cambiarEstado(String id, String estado) async {
    setState(() => _accionando = true);
    final caso = sl<CambiarEstadoAlertaUseCase>();
    final r = await caso(id, estado);
    if (!mounted) return;
    setState(() => _accionando = false);
    if (r case Err(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alerta $estado')));
    await _cargar();
  }

  @override
  void dispose() {
    _alertaSub?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis alertas')),
        body: Center(child: Text(_error!)),
      );
    }

    final asignada = _alertas.where((a) => a['asignadaAMiUnidad'] == true || a['estado'] == 'ACEPTADA').cast<Map<String, dynamic>>().toList();
    final activas = _alertas.where((a) => a['estado'] == 'ACTIVA').cast<Map<String, dynamic>>().toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') context.read<AuthBloc>().add(const AuthLogoutSolicitado());
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('Cerrar sesion'))],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (asignada.isNotEmpty) ...[
            const Text('Mi alerta asignada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...asignada.map((a) => _AlertaAsignadaCard(alerta: a, accionando: _accionando, onEstado: _cambiarEstado)),
            const SizedBox(height: 16),
          ],
          const Text('Alertas activas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (activas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No hay alertas activas.')),
            )
          else
            ...activas.map((a) => _AlertaActivaCard(alerta: a, accionando: _accionando, onAceptar: () => _cambiarEstado(a['id'].toString(), 'ACEPTADA'))),
        ],
      ),
    );
  }
}

class _AlertaActivaCard extends StatelessWidget {
  const _AlertaActivaCard({required this.alerta, required this.accionando, required this.onAceptar});
  final Map<String, dynamic> alerta;
  final bool accionando;
  final VoidCallback onAceptar;

  @override
  Widget build(BuildContext context) {
    final direccion = (alerta['direccion'] ?? 'Sin direccion').toString();
    final creada = DateTime.tryParse(alerta['creadaEn']?.toString() ?? '')?.toLocal();
    return Card(
      child: ListTile(
        title: Text(direccion),
        subtitle: Text(creada != null ? 'Recibida: ${_hora(creada)}' : 'Alerta activa'),
        trailing: FilledButton(
          onPressed: accionando ? null : onAceptar,
          child: const Text('Aceptar'),
        ),
      ),
    );
  }
}

class _AlertaAsignadaCard extends StatelessWidget {
  const _AlertaAsignadaCard({required this.alerta, required this.accionando, required this.onEstado});
  final Map<String, dynamic> alerta;
  final bool accionando;
  final Future<void> Function(String id, String estado) onEstado;

  @override
  Widget build(BuildContext context) {
    final id = alerta['id']?.toString() ?? '';
    final lat = (alerta['latitud'] as num?)?.toDouble();
    final lon = (alerta['longitud'] as num?)?.toDouble();
    final punto = (lat != null && lon != null) ? LatLng(lat, lon) : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((alerta['direccion'] ?? 'Ciudadano con SOS').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Estado: ${alerta['estado'] ?? ''}'),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(initialCenter: punto ?? const LatLng(-3.4825, -80.245), initialZoom: punto != null ? 16 : 13),
                children: [
                  MapTiles.capaBase(),
                  if (punto != null)
                    MarkerLayer(markers: [Marker(point: punto, width: 36, height: 36, child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 36))]),
                  MapTiles.atribucionWidget(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: accionando ? null : () => onEstado(id, 'ATENDIDA'),
                  child: const Text('Atendida'),
                ),
                OutlinedButton(
                  onPressed: accionando ? null : () => onEstado(id, 'CANCELADA'),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _hora(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}