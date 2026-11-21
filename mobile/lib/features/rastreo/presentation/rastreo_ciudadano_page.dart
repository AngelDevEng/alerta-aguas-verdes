import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get_it/get_it.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/maps/map_tiles.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/sos_session_store.dart';

/// Seguimiento de la SOS del ciudadano.
///
/// Usa `GET /alertas/:id/seguimiento` con `X-Session-Token`: el ciudadano no
/// tiene JWT, asi que el `GET /alertas/:id` autenticado devolveria 401. El
/// token se recibe al crear la alerta y se guarda en [SosSessionStore] para
/// reabrir la pantalla despues de cerrar la app.
class RastreoCiudadanoPage extends StatefulWidget {
  const RastreoCiudadanoPage({
    super.key,
    required this.alertaId,
    this.sessionToken,
  });

  final String alertaId;
  final String? sessionToken;

  @override
  State<RastreoCiudadanoPage> createState() => _RastreoCiudadanoPageState();
}

class _RastreoCiudadanoPageState extends State<RastreoCiudadanoPage> {
  final SosSessionStore _store = SosSessionStore();
  Timer? _timer;
  bool _detenido = false;
  String? _estado;
  String? _unidadId;
  Map<String, dynamic>? _sereno;
  List<dynamic> _puntosCiudadano = [];
  String? _error;

  /// Capa base creada una sola vez: el polling cada 5 s reconstruye el widget,
  /// y recrear el `TileLayer` en cada rebuild dispara peticiones de tiles.
  late final TileLayer _capaBase = MapTiles.capaBase();

  Dio? get _dio => GetIt.I.isRegistered<ApiClient>()
      ? GetIt.I<ApiClient>().dio
      : null;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_detenido) return;
    try {
      final token = widget.sessionToken ?? (await _store.read())?.sessionToken;
      if (token == null || token.isEmpty) {
        _fallo('No hay una sesion de seguimiento activa.');
        return;
      }

      final dio = _dio;
      if (dio == null) {
        _fallo('No se pudo iniciar el seguimiento.');
        return;
      }

      final r = await dio.get<dynamic>(
        '/alertas/${widget.alertaId}/seguimiento',
        options: Options(headers: {'X-Session-Token': token}),
      );

      final data = r.data;
      if (data is! Map) {
        _fallo('El servidor devolvio una respuesta inesperada.');
        return;
      }

      final alerta = data['alerta'];
      final sereno = data['sereno'];
      final ciudadano = data['ciudadano'];

      if (!mounted) return;
      setState(() {
        _error = null;
        _estado = alerta is Map ? alerta['estado'] as String? : null;
        _unidadId = alerta is Map
            ? (alerta['unidadId'] as String? ??
                alerta['unidadAsignadaId'] as String?)
            : null;
        _sereno = sereno is Map
            ? Map<String, dynamic>.from(sereno)
            : null;
        _puntosCiudadano = ciudadano is Map && ciudadano['ubicaciones'] is List
            ? (ciudadano['ubicaciones'] as List)
            : const [];
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 404) {
        await _store.clear();
        _fallo('La alerta ya no esta activa.');
        return;
      }
      _fallo('No se pudo actualizar el seguimiento. Revisa tu conexion.');
    } catch (_) {
      _fallo('No se pudo actualizar el seguimiento. Revisa tu conexion.');
    }
  }

  void _fallo(String mensaje) {
    if (!mounted) return;
    setState(() {
      _error = mensaje;
      _detenido = true;
    });
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _estado == null
        ? 'Rastreo ciudadano'
        : 'Rastreo ciudadano ($_estado)';

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rastreo ciudadano')),
        body: Center(child: Text(_error!)),
      );
    }

    final puntosCiudadano = _puntosCiudadano
        .where((p) => p is Map && p['latitud'] != null && p['longitud'] != null)
        .map((p) => LatLng(
              (p['latitud'] as num).toDouble(),
              (p['longitud'] as num).toDouble(),
            ))
        .toList();

    final sereno = _sereno;
    final latSereno = sereno?['latitud'];
    final lonSereno = sereno?['longitud'];
    final posicionSereno = (latSereno != null && lonSereno != null)
        ? LatLng((latSereno as num).toDouble(), (lonSereno as num).toDouble())
        : null;

    final todos = <LatLng>[...puntosCiudadano];
    if (posicionSereno != null) todos.add(posicionSereno);

    final centro = todos.isNotEmpty
        ? LatLng(
            todos.map((e) => e.latitude).reduce((a, b) => a + b) /
                todos.length,
            todos.map((e) => e.longitude).reduce((a, b) => a + b) /
                todos.length,
          )
        : const LatLng(-3.4825, -80.245);

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: centro,
                initialZoom: todos.isNotEmpty ? 15 : 13,
              ),
              children: [
                _capaBase,
                MarkerLayer(
                  markers: [
                    ...puntosCiudadano.map(
                      (p) => Marker(
                        point: p,
                        width: 24,
                        height: 24,
                        child: const Icon(
                          Icons.person_pin,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                    ),
                    if (posicionSereno != null)
                      Marker(
                        point: posicionSereno,
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.local_police,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                  ],
                ),
                MapTiles.atribucionWidget(),
              ],
            ),
          ),
          if (_sereno == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Esperando asignacion de unidad...',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_police, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Unidad ${_unidadId ?? ''} en ruta',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}