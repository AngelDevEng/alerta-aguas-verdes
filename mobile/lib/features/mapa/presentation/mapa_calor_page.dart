import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/maps/map_tiles.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../../incidencias/domain/entities/tipo_incidencia.dart';

class MapaCalorPage extends StatefulWidget {
  const MapaCalorPage({super.key});
  @override
  State<MapaCalorPage> createState() => _MapaCalorPageState();
}

class _MapaCalorPageState extends State<MapaCalorPage> {
  final TokenStore _store = TokenStore();
  Dio get _dio => GetIt.I<ApiClient>().dio;
  List<Map<String, dynamic>> _zonas = [];
  DateTime? _desde;
  DateTime? _hasta;
  int? _tipoId;
  bool _cargando = false;
  String? _error;

  /// Capa base creada una sola vez: recrearla en cada rebuild multiplica las
  /// peticiones de tiles y el riesgo de 403/429 del proveedor.
  late final TileLayer _capaBase = MapTiles.capaBase();

  static const _centro = LatLng(-3.4812, -80.2454);
  static final _fechaFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final token = await _store.readAccess();
      final params = <String, dynamic>{};
      if (_desde != null) params['desde'] = _desde!.toUtc().toIso8601String();
      if (_hasta != null) {
        final h = DateTime(_hasta!.year, _hasta!.month, _hasta!.day, 23, 59, 59);
        params['hasta'] = h.toUtc().toIso8601String();
      }
      final tipo = _tipoId == null ? null : TiposIncidencia.porId(_tipoId!);
      if (tipo != null) params['tipo'] = tipo.codigo;
      final r = await _dio.get<dynamic>(
        '/incidencias/zonas-calor',
        queryParameters: params,
        options: Options(headers: token == null ? null : {'Authorization': 'Bearer $token'}),
      );
      final data = r.data;
      if (!mounted) return;
      setState(() {
        _zonas = data is List
            ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el mapa de calor.';
        _cargando = false;
      });
    }
  }

  Future<void> _elegirFecha({required bool desde}) async {
    final actual = desde ? _desde : _hasta;
    final picked = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: desde ? 'Desde' : 'Hasta',
    );
    if (picked == null) return;
    setState(() {
      if (desde) {
        _desde = picked;
        if (_hasta != null && _hasta!.isBefore(picked)) _hasta = picked;
      } else {
        _hasta = picked;
        if (_desde != null && _desde!.isAfter(picked)) _desde = picked;
      }
    });
  }

  void _limpiar() {
    setState(() {
      _desde = null;
      _hasta = null;
      _tipoId = null;
    });
    _cargar();
  }

  Color _colorPorPeso(int peso) {
    if (peso >= 9) return Colors.red.withValues(alpha: 0.55);
    if (peso >= 4) return Colors.orange.withValues(alpha: 0.55);
    return Colors.yellow.withValues(alpha: 0.55);
  }

  double _radioPorPeso(int peso) {
    if (peso >= 9) return 22;
    if (peso >= 4) return 16;
    return 12;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de calor'),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh), tooltip: 'Recargar'),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('calor_desde'),
                        onPressed: () => _elegirFecha(desde: true),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(_desde == null ? 'Desde' : _fechaFmt.format(_desde!)),
                      ),
                      OutlinedButton.icon(
                        key: const Key('calor_hasta'),
                        onPressed: () => _elegirFecha(desde: false),
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(_hasta == null ? 'Hasta' : _fechaFmt.format(_hasta!)),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<int?>(
                          key: const Key('calor_tipo'),
                          initialValue: _tipoId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de incidente',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Todos los tipos')),
                            ...TiposIncidencia.porDefecto.map(
                              (t) => DropdownMenuItem<int?>(value: t.id, child: Text(t.nombre, overflow: TextOverflow.ellipsis)),
                            ),
                          ],
                          onChanged: (v) => setState(() => _tipoId = v),
                        ),
                      ),
                      FilledButton(onPressed: _cargar, child: const Text('Aplicar')),
                      TextButton(onPressed: _limpiar, child: const Text('Limpiar')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: const [
                      _LeyendaCalor(color: Colors.yellow, texto: '1-3'),
                      _LeyendaCalor(color: Colors.orange, texto: '4-8'),
                      _LeyendaCalor(color: Colors.red, texto: '9+'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_cargando) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [Expanded(child: Text(_error!)), TextButton(onPressed: _cargar, child: const Text('Reintentar'))]),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: const MapOptions(initialCenter: _centro, initialZoom: 14),
                  children: [
                    _capaBase,
                    CircleLayer(
                      circles: _zonas.map((z) {
                        final peso = (z['peso'] as num?)?.toInt() ?? 1;
                        final lat = (z['lat'] as num?)?.toDouble();
                        final lng = (z['lng'] as num?)?.toDouble();
                        if (lat == null || lng == null) return null;
                        final r = _radioPorPeso(peso);
                        return CircleMarker(
                          point: LatLng(lat, lng),
                          radius: r,
                          useRadiusInMeter: false,
                          color: _colorPorPeso(peso),
                          borderColor: _colorPorPeso(peso).withValues(alpha: 0.9),
                          borderStrokeWidth: 1,
                        );
                      }).whereType<CircleMarker>().toList(),
                    ),
                    MapTiles.atribucionWidget(),
                  ],
                ),
                if (!_cargando && _zonas.isEmpty && _error == null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'No hay incidentes para los filtros seleccionados.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeyendaCalor extends StatelessWidget {
  const _LeyendaCalor({required this.color, required this.texto});
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color.withValues(alpha: 0.7), shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
