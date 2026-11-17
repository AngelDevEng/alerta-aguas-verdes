import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: _sereno == null
          ? const Center(child: Text('Esperando asignacion de unidad...'))
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.local_police),
                  title: Text('Unidad ${_unidadId ?? ''}'),
                  subtitle: Text(
                    '${_sereno!['latitud'] ?? '?'}, ${_sereno!['longitud'] ?? '?'}',
                  ),
                ),
                const Divider(),
                const ListTile(
                  title: Text('Mi ubicacion reportada'),
                  subtitle: Text('Se comparte cuando un sereno acepta.'),
                ),
                ..._puntosCiudadano.map(
                  (p) => ListTile(
                    title: Text('${p['latitud']}, ${p['longitud']}'),
                    subtitle: Text('${p['registradoEn'] ?? ''}'),
                  ),
                ),
              ],
            ),
    );
  }
}