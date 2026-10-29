import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../incidencias/domain/entities/incidencia.dart';
import '../../../incidencias/domain/entities/incidencia_mapa.dart';
import '../../../incidencias/presentation/widgets/incidencia_badges.dart';
import '../bloc/mapa_bloc.dart';
import '../bloc/mapa_event.dart';
import '../bloc/mapa_state.dart';

/// Mapa operativo con OpenStreetMap (`flutter_map`), equivalent al mapa del
/// legacy (`RastreoActivity`, `MapaCalorActivity` y `MonitoreoActivity` usaban
/// osmdroid con la misma fuente MAPNIK, sin clave).
///
/// Fuentes de datos:
///
/// - incidencias: `GET /incidencias/geojson` (capa que dibuja el BLoC),
/// - mi posicion: `LocationService`, para centrar y para el marcador propio.
///
/// El seguimiento en vivo de patrulla y alerta (5 s / 7 s del legacy) entra en
/// 4d.4; esta pantalla trae el mapa y sus capas.
class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  /// Centro por defecto: el mismo punto que fijan `MapaCalorActivity:114`,
  /// `MonitoreoActivity:78` y `RastreoActivity:79` del legacy. No es la
  /// posicion del usuario: es el centro de Aguas Verdes, para que sin GPS el
  /// mapa salga encuadrado en vez de en Ucrania (el default de flutter_map).
  static const _centroPorDefecto = LatLng(-3.4812, -80.2454);

  /// Zoom de distrito, el de `MapaCalorActivity:113`: alcanza para ver todas
  /// las incidencias de una vez sin entrar a la calle.
  static const _zoomPorDefecto = 14.0;

  /// Zoom cuando el mapa se centra en el usuario. Entre el 15 de
  /// `MonitoreoActivity` y el 17 de `RastreoActivity`: a 16 se ve la cuadra
  /// exacta sin perder el entorno inmediato.
  static const _zoomMiPosicion = 16.0;

  /// Tile source de OSM, la misma MAPNIK que usa el legacy.
  static const _tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  final MapController _mapa = MapController();

  @override
  void dispose() {
    _mapa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa operativo'),
        actions: [
          IconButton(
            key: const Key('mapa_recargar'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () =>
                context.read<MapaBloc>().add(const CargarMapa()),
          ),
        ],
      ),
      // El FAB vive fuera del Stack para que Scaffold respete el safe area y
      // no quede debajo de la barra de navegacion.
      floatingActionButton: BlocBuilder<MapaBloc, MapaState>(
        buildWhen: (anterior, actual) =>
            (anterior is MapaListos) != (actual is MapaListos),
        builder: (context, state) => state is MapaListos
            ? FloatingActionButton.small(
                key: const Key('mapa_centrar'),
                tooltip: 'Centrar en mi ubicacion',
                onPressed: () =>
                    context.read<MapaBloc>().add(const CentrarEnMi()),
                child: const Icon(Icons.my_location),
              )
            : const SizedBox.shrink(),
      ),
      body: BlocConsumer<MapaBloc, MapaState>(
        listener: _alCambiarEstado,
        builder: (context, state) => Stack(
          children: [
            FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: _centroPorDefecto,
                initialZoom: _zoomPorDefecto,
                // Sin rotacion: un mapa girado hace que el operador lea mal
                // las calles, y el legacy tampoco la habilitaba.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: _tiles,
                  // Politica de uso de tile.openstreetmap.org: identificar la
                  // app en el User-Agent. Sin esto el tile server puede banear.
                  userAgentPackageName: 'pe.gob.municaguasverdes.app',
                  maxZoom: 19,
                ),
                MarkerLayer(markers: _marcadores(state)),
                const SimpleAttributionWidget(
                  source: Text('© Colaboradores de OpenStreetMap'),
                ),
              ],
            ),
            if (state is MapaInicial || state is MapaCargando)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (state case MapaError(:final mensaje))
              Positioned.fill(
                child: _Fallo(
                  mensaje: mensaje,
                  onReintentar: () =>
                      context.read<MapaBloc>().add(const CargarMapa()),
                ),
              ),
            if (state is MapaListos)
              const Positioned(left: 12, bottom: 12, child: _Leyenda()),
          ],
        ),
      ),
    );
  }

  /// Centra el mapa cuando llega una posicion nueva y muestra el aviso
  /// (normalmente un fallo de GPS) si lo hay.
  ///
  /// Toda emision de [MapaListos] con posicion vuelve a centrar: incluye la
  /// recarga, que re-pide el GPS. Si el operador habia panorado a otra zona
  /// y recarga, volver a si mismo es el comportamiento esperado de
  /// "recargar".
  void _alCambiarEstado(BuildContext context, MapaState state) {
    if (state is! MapaListos) return;

    final aviso = state.aviso;
    if (aviso != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(aviso)));
    }

    final posicion = state.miPosicion;
    if (posicion != null) {
      _mapa.move(
        LatLng(posicion.latitud, posicion.longitud),
        _zoomMiPosicion,
      );
    }
  }

  /// La capa de marcadores del estado actual.
  ///
  /// Los puntos son chicas a proposito: `GET /incidencias/geojson` trae hasta
  /// 1000 incidencias y un marcador del tamano del legacy (48 dp, pensado para
  /// los dos marcadores de `RastreoActivity`) taparia el distrito entero. El
  /// area de toque si se agranda hasta 34 dp, con el circulo centrado adentro.
  List<Marker> _marcadores(MapaState state) {
    if (state is! MapaListos) return const [];
    final posicion = state.miPosicion;

    return [
      for (final incidencia in state.incidencias)
        Marker(
          point: LatLng(incidencia.latitud, incidencia.longitud),
          width: 34,
          height: 34,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _mostrarDetalle(incidencia),
            child: Center(child: _Circulo(color: colorDePrioridad(context, incidencia.prioridad))),
          ),
        ),
      if (posicion != null)
        Marker(
          key: const Key('mi_posicion'),
          point: LatLng(posicion.latitud, posicion.longitud),
          width: 34,
          height: 34,
          child: Center(child: _Circulo(color: context.legacy.azul, radio: 11)),
        ),
    ];
  }

  void _mostrarDetalle(IncidenciaMapa incidencia) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                incidencia.codigo,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                incidencia.tipo,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  EstadoBadge(estado: incidencia.estado),
                  PrioridadBadge(prioridad: incidencia.prioridad),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circulo relleno con anillo blanco, el mismo estilo del
/// `generarIconoCirculo` de `RastreoActivity.kt:160`.
class _Circulo extends StatelessWidget {
  const _Circulo({required this.color, this.radio = 8});

  final Color color;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radio * 2,
      height: radio * 2,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

/// Leyenda de colores del mapa. Sin esto los colores de prioridad son
/// adivinanza: la misma paleta se explica en las pastillas de la lista.
class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    const entradas = <(Prioridad, String)>[
      (Prioridad.critica, 'Crítica'),
      (Prioridad.alta, 'Alta'),
      (Prioridad.media, 'Media'),
      (Prioridad.baja, 'Baja'),
    ];

    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (prioridad, texto) in entradas)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Circulo(color: colorDePrioridad(context, prioridad), radio: 5),
                    const SizedBox(width: 6),
                    Text(texto, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Capa de error: el geojson fallo, asi que no hay puntos que dibujar.
class _Fallo extends StatelessWidget {
  const _Fallo({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final superficie = Theme.of(context).colorScheme.surface;
    return ColoredBox(
      color: superficie.withValues(alpha: 0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56),
              const SizedBox(height: 12),
              Text(mensaje, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onReintentar, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}
