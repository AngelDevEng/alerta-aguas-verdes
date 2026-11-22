import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get_it/get_it.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart';
import '../../../core/maps/map_tiles.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/sos_session_store.dart';

/// Seguimiento de la SOS del ciudadano.
///
/// Usa `GET /alertas/:id/seguimiento` con `X-Session-Token`: el ciudadano no
/// tiene JWT. Muestra estado, trazabilidad, unidad asignada (codigo/placa),
/// posicion del sereno, su propia posicion y ETA estimada.
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
  Map<String, dynamic>? _sereno;
  List<dynamic> _puntosCiudadano = [];
  List<dynamic> _historial = [];
  String? _error;
  LatLng? _miPosicion;
  DateTime? _ultimaActualizacion;

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

      await _capturarMiPosicion(token);

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
      final historial = data['historial'];

      if (!mounted) return;
      setState(() {
        _error = null;
        _estado = alerta is Map ? alerta['estado'] as String? : null;
        _sereno = sereno is Map ? Map<String, dynamic>.from(sereno) : null;
        _puntosCiudadano = ciudadano is Map && ciudadano['ubicaciones'] is List
            ? (ciudadano['ubicaciones'] as List)
            : const [];
        _historial = historial is List ? historial : const [];
        _ultimaActualizacion = DateTime.now();
      });

      if (_estado != null && const {'ATENDIDA', 'CANCELADA', 'FALSA', 'EXPIRADA'}.contains(_estado)) {
        await _store.clear();
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 404) {
        await _store.clear();
        _fallo('La alerta ya no esta activa.');
        return;
      }
      _falloSuave('No se pudo actualizar el seguimiento. Revisa tu conexion.');
    } catch (_) {
      _falloSuave('No se pudo actualizar el seguimiento. Revisa tu conexion.');
    }
  }

  Future<void> _capturarMiPosicion(String token) async {
    if (!GetIt.I.isRegistered<LocationService>()) return;
    final pos = await GetIt.I<LocationService>().posicionActual();
    if (!mounted) return;
    pos.fold(
      (_) {},
      (p) {
        _miPosicion = LatLng(p.latitud, p.longitud);
        final dio = _dio;
        if (dio != null) {
          dio
              .post<void>(
                '/alertas/${widget.alertaId}/posicion',
                data: {
                  'latitud': p.latitud,
                  'longitud': p.longitud,
                },
                options: Options(headers: {'X-Session-Token': token}),
              )
              .ignore();
        }
      },
    );
  }

  void _fallo(String mensaje) {
    if (!mounted) return;
    setState(() {
      _error = mensaje;
      _detenido = true;
    });
    _timer?.cancel();
  }

  void _falloSuave(String mensaje) {
    if (!mounted) return;
    setState(() => _error = mensaje);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _estado == null ? 'Mi alerta SOS' : 'Mi alerta SOS ($_estado)';

    if (_error != null && _estado == null && _sereno == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi alerta SOS')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final puntosCiudadano = _puntosCiudadano
        .where((p) => p is Map && p['latitud'] != null && p['longitud'] != null)
        .map((p) => LatLng(
              (p['latitud'] as num).toDouble(),
              (p['longitud'] as num).toDouble(),
            ))
        .toList();
    if (_miPosicion != null) {
      puntosCiudadano.insert(0, _miPosicion!);
    }

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
            todos.map((e) => e.latitude).reduce((a, b) => a + b) / todos.length,
            todos.map((e) => e.longitude).reduce((a, b) => a + b) / todos.length,
          )
        : const LatLng(-3.4825, -80.245);

    final etiquetaUnidad = _etiquetaUnidad(sereno);
    final eta = _etaMinutos(posicionSereno, puntosCiudadano.isNotEmpty ? puntosCiudadano.first : null);

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              backgroundColor: const Color(0xFFFFF3CD),
              actions: [TextButton(onPressed: _poll, child: const Text('Reintentar'))],
            ),
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
                    ...puntosCiudadano.take(1).map(
                          (p) => Marker(
                            point: p,
                            width: 34,
                            height: 34,
                            child: const Icon(Icons.my_location, color: Colors.green, size: 32),
                          ),
                        ),
                    if (posicionSereno != null)
                      Marker(
                        point: posicionSereno,
                        width: 34,
                        height: 34,
                        child: const Icon(Icons.local_police, color: Colors.blue, size: 32),
                      ),
                  ],
                ),
                MapTiles.atribucionWidget(),
              ],
            ),
          ),
          _PanelSeguimiento(
            estado: _estado,
            etiquetaUnidad: etiquetaUnidad,
            etaMinutos: eta,
            ultimaActualizacion: _ultimaActualizacion,
            historial: _historial,
            tengoUbicacion: _miPosicion != null || puntosCiudadano.isNotEmpty,
          ),
        ],
      ),
    );
  }

  String _etiquetaUnidad(Map<String, dynamic>? sereno) {
    if (sereno == null) return 'Esperando asignacion de unidad...';
    final placa = (sereno['placa'] as String?)?.trim();
    final codigo = (sereno['codigo'] as String?)?.trim();
    final tipo = (sereno['tipo'] as String?)?.trim();
    final partes = <String>[
      if (placa != null && placa.isNotEmpty) placa,
      if (codigo != null && codigo.isNotEmpty) codigo,
      if (tipo != null && tipo.isNotEmpty) tipo,
    ];
    if (partes.isEmpty) return 'Unidad asignada';
    return partes.join(' · ');
  }

  int? _etaMinutos(LatLng? unidad, LatLng? destino) {
    if (unidad == null || destino == null) return null;
    final metros = _distanciaMetros(unidad, destino);
    // Heuristica conservadora urbana: 20 km/h. Se muestra como estimado.
    final minutos = (metros / (20000 / 60)).ceil();
    return minutos.clamp(1, 120);
  }

  double _distanciaMetros(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  double _rad(double deg) => deg * math.pi / 180;
}

class _PanelSeguimiento extends StatelessWidget {
  const _PanelSeguimiento({
    required this.estado,
    required this.etiquetaUnidad,
    required this.etaMinutos,
    required this.ultimaActualizacion,
    required this.historial,
    required this.tengoUbicacion,
  });

  final String? estado;
  final String etiquetaUnidad;
  final int? etaMinutos;
  final DateTime? ultimaActualizacion;
  final List<dynamic> historial;
  final bool tengoUbicacion;

  @override
  Widget build(BuildContext context) {
    final terminal = const {'ATENDIDA', 'CANCELADA', 'FALSA', 'EXPIRADA'}.contains(estado);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  terminal ? Icons.check_circle : Icons.local_police,
                  color: terminal ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    etiquetaUnidad,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _mensajeEstado(estado, etaMinutos),
              style: const TextStyle(fontSize: 14),
            ),
            if (!tengoUbicacion)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'No pudimos obtener tu ubicacion actual. La alerta sigue activa; si puedes, llama a la central.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            if (ultimaActualizacion != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Actualizado: ${_hora(ultimaActualizacion!)}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            if (historial.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Trazabilidad', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...historial.take(5).map((h) {
                if (h is! Map) return const SizedBox.shrink();
                final e = (h['estado'] ?? '').toString();
                final t = h['registradoEn']?.toString();
                final dt = t == null ? null : DateTime.tryParse(t)?.toLocal();
                return Text(
                  '• $e${dt != null ? ' · ${_hora(dt)}' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _mensajeEstado(String? estado, int? eta) {
    switch (estado) {
      case 'ACTIVA':
        return 'Tu SOS fue enviada. Esperando que una unidad la acepte.';
      case 'ACEPTADA':
        if (eta != null) return 'Unidad en camino. Llegada estimada: ~$eta min (aprox.).';
        return 'Unidad asignada. Esperando ubicacion de la unidad.';
      case 'ATENDIDA':
        return 'Tu alerta fue atendida.';
      case 'CANCELADA':
      case 'FALSA':
      case 'EXPIRADA':
        return 'Tu alerta ya no esta activa ($estado).';
      default:
        return 'Actualizando estado de tu alerta...';
    }
  }

  String _hora(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}