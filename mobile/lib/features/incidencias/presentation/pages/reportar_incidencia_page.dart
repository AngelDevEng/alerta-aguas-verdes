import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/result.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/evidencia.dart';
import '../../domain/entities/incidencia.dart';
import '../../domain/entities/tipo_incidencia.dart';
import '../bloc/reportar_bloc.dart';
import '../bloc/reportar_event.dart';
import '../bloc/reportar_state.dart';
import '../constantes_reporte.dart';
import '../widgets/envio_en_curso.dart';
import '../widgets/formulario_reporte.dart';

/// Formulario de reporte de incidencia.
///
/// Sustituye al placeholder. El flujo real es:
/// 1. Elegir tipo, descripcion, prioridad y referencia.
/// 2. Obtener la ubicacion con el GPS (obligatoria: el backend la exige).
/// 3. Adjuntar hasta [maxFotos] fotos, opcional.
/// 4. Enviar. El BLoC hace el alta y despues sube las fotos.
///
/// Los pasos 1 a 3 son estado local de la pantalla: todavia no se toco el
/// servidor. El paso 4 es el unico que despacha eventos al BLoC.
class ReportarIncidenciaPage extends StatefulWidget {
  const ReportarIncidenciaPage({super.key});

  /// Las constantes de tope viven en `constantes_reporte.dart` para que la
  /// pagina y los widgets las compartan sin importarse entre si.
  static const double maxLado = kMaxLadoFoto;
  static const int maxFotos = kMaxFotosReporte;

  @override
  State<ReportarIncidenciaPage> createState() => _ReportarIncidenciaPageState();
}

class _ReportarIncidenciaPageState extends State<ReportarIncidenciaPage> {
  final _formKey = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _referencia = TextEditingController();

  final _imagenes = ImagePicker();

  TipoIncidencia? _tipo;
  Prioridad? _prioridad;
  List<XFile> _fotos = const [];
  PosicionActual? _posicion;
  bool _ubicando = false;

  @override
  void initState() {
    super.initState();
    // El reporte arranca pidiendo la ubicacion: es el dato que mas cuesta
    // obtener (hay que abrir ajustes si el permiso esta denegado) y sin el
    // cual el backend rechaza el alta. Pedirlo de entrada evita que el usuario
    // escriba todo y despues descubra que no puede enviar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ubicar());
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _referencia.dispose();
    super.dispose();
  }

  /// Pide la posicion al GPS y la guarda en el estado local.
  Future<void> _ubicar() async {
    if (_ubicando) return;
    setState(() => _ubicando = true);

    final resultado = await context.read<LocationService>().posicionActual();
    if (!mounted) return;
    setState(() => _ubicando = false);

    switch (resultado) {
      case Ok(:final value):
        setState(() => _posicion = value);
      case Err(:final failure):
        _avisar(failure.message);
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _agregarFoto(ImageSource origen) async {
    if (_fotos.length >= ReportarIncidenciaPage.maxFotos) return;

    try {
      final x = await _imagenes.pickImage(
        source: origen,
        // Recortar en el dispositivo: baja los bytes antes de subir y evita
        // comerse el limite de 15 MB del backend.
        maxWidth: ReportarIncidenciaPage.maxLado,
        maxHeight: ReportarIncidenciaPage.maxLado,
        imageQuality: 85,
      );
      if (x == null || !mounted) return;

      final tamano = await File(x.path).length();
      if (tamano > EvidenciaAdjunta.maxBytes) {
        _avisar('La foto pesa ${(tamano / 1048576).toStringAsFixed(1)} MB y el '
            'maximo son ${EvidenciaAdjunta.maxBytes ~/ 1048576} MB.');
        return;
      }

      setState(() => _fotos = [..._fotos, x]);
    } catch (e) {
      _avisar('No se pudo abrir la camara o la galeria: $e');
    }
  }

  /// Valida y despacha el reporte.
  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    final tipo = _tipo;
    final posicion = _posicion;
    if (tipo == null) {
      _avisar('Elegi el tipo de incidencia.');
      return;
    }
    if (posicion == null) {
      _avisar('Falta la ubicacion. Toque "Actualizar ubicacion".');
      return;
    }

    context.read<ReportarBloc>().add(ReportarSolicitado(
          datos: NuevaIncidencia(
            tipoId: tipo.id,
            latitud: posicion.latitud,
            longitud: posicion.longitud,
            descripcion: _descripcion.text,
            prioridad: _prioridad,
            referencia: _referencia.text,
            ocurridoEn: DateTime.now(),
          ),
          // La foto hereda la ubicacion del reporte: es lo que el operador
          // necesita para ubicar la evidencia, y el backend solo la guarda si
          // llegan las dos coordenadas.
          evidencias: [
            for (final f in _fotos)
              EvidenciaAdjunta(
                ruta: f.path,
                nombre: f.name,
                latitud: posicion.latitud,
                longitud: posicion.longitud,
              ),
          ],
        ));
  }

  /// Nombre legible del lugar, aproximado por geocoding inverso.
  ///
  /// Es una comodidad, no un dato critico: si falla la red se muestra solo el
  /// boton de actualizar, sin bloquear el reporte.
  Future<String> _lugarDe(PosicionActual p) async {
    try {
      final placemarks = await placemarkFromCoordinates(p.latitud, p.longitud);
      if (placemarks.isEmpty) return '';
      final m = placemarks.first;
      // `subLocality` y `locality` vienen nullable desde el servicio de
      // geocoding: se filtran los vacios y se deduplican porque a veces el
      // pueblo y el distrito traen el mismo texto.
      final partes = [
        if (m.subLocality != null) m.subLocality!.trim(),
        if (m.locality != null) m.locality!.trim(),
      ].where((s) => s.isNotEmpty).toSet().join(', ');
      return partes;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportarBloc, ReportarState>(
      listenWhen: (a, b) => b is ReportarExito || b is ReportarError,
      listener: (context, state) {
        switch (state) {
          case ReportarExito(:final parcial, :final fotosSubidas, :final fotosFallidas):
            _onExito(context, parcial, fotosSubidas, fotosFallidas);
          case ReportarError(:final mensaje):
            _avisar(mensaje);
          default:
            break;
        }
      },
      builder: (context, state) {
        final enviando = state is ReportarEnviando;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Reportar incidencia'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar sin reportar',
              onPressed: enviando ? null : () => Navigator.of(context).pop(),
            ),
          ),
          body: enviando
              ? EnvioEnCurso(estado: state)
              : FormularioReporte(
                  formKey: _formKey,
                  descripcion: _descripcion,
                  referencia: _referencia,
                  tipo: _tipo,
                  prioridad: _prioridad,
                  fotos: _fotos,
                  posicion: _posicion,
                  ubicando: _ubicando,
                  exitoPrevio: state is ReportarExito ? state : null,
                  onTipo: (t) => setState(() => _tipo = t),
                  onPrioridad: (p) => setState(() => _prioridad = p),
                  onUbicacion: _ubicar,
                  onCamara: () => _agregarFoto(ImageSource.camera),
                  onGaleria: () => _agregarFoto(ImageSource.gallery),
                  onQuitarFoto: (i) => setState(() {
                    final copia = [..._fotos]..removeAt(i);
                    _fotos = copia;
                  }),
                  onReintentarFotos: () => context
                      .read<ReportarBloc>()
                      .add(const ReintentarEvidencias()),
                  lugarDe: _lugarDe,
                ),
          bottomNavigationBar: enviando
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      // El envio se habilita con ubicacion porque sin ella el
                      // backend devuelve 400.
                      onPressed: _posicion == null ? null : _enviar,
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar reporte'),
                    ),
                  ),
                ),
        );
      },
    );
  }

  void _onExito(
    BuildContext context,
    bool parcial,
    int fotosSubidas,
    int fotosFallidas,
  ) {
    if (parcial) {
      // El reporte SI quedo guardado. Decir "error" seria mentir y empujaria a
      // duplicarlo.
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: Icon(Icons.check_circle, color: context.legacy.verde),
          title: const Text('Reporte guardado'),
          content: Text(
            'La incidencia se registro, pero $fotosFallidas '
            '${fotosFallidas == 1 ? "foto no se pudo" : "fotos no se pudieron"} '
            'subir (${fotosSubidas == 1 ? "1 subida" : "$fotosSubidas subidas"}).',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<ReportarBloc>().add(const ReintentarEvidencias());
              },
              child: const Text('Reintentar fotos'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }
}
