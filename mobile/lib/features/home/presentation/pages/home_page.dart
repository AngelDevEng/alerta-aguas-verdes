import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../alertas/presentation/bloc/sos_bloc.dart';
import '../../../alertas/presentation/bloc/sos_event.dart';
import '../../../alertas/presentation/bloc/sos_state.dart';
import '../../../auth/domain/entities/usuario.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../unidades/domain/usecases/unidad_usecases.dart';

/// Home: menu principal post-login.
///
/// Replica 1:1 `MenuActivity` + `activity_menu.xml` del legacy:
///
/// - misma imagen de fondo (`@mipmap/menu`),
/// - toolbar translucido `#80000000` con "Menú Principal" (o "Panel Patrulla:
///   `<placa>`" para SERENO, que es el `PATRULLERO` del legacy),
/// - botones graficos en las mismas posiciones (bias verticales 0.344 / 0.544
///   / 0.723 de la ConstraintLayout original),
/// - misma visibilidad por rol: sereno ve panel de patrulla + rastreo; el
///   resto ve SOS + Emergencia,
/// - mismos botones inferiores: Reportar Incidente `#D32F2F` y Mapa de Calor
///   `#FF9800`.
///
/// Sin accesos extra: Incidencias/Perfil/Mapa operativo no estaban en el menu
/// legacy y se quitaron por decision del usuario (1:1 estricto). El panel CRUD
/// del ADMIN (`MainActivity` legacy) es otra tarea.
///
/// Acciones todavia no implementadas en Flutter (buscar placa, rastreo, mapa
/// de calor) quedan visibles con el mismo look y muestran un aviso, para que
/// la pantalla sea 1:1 aunque la funcion llegue despues (rastreo 4d.4, mapa
/// de calor 4d.7). El SOS si esta conectado: posicion + `POST /alertas` (4d.2).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SosBloc>(
      create: (_) => GetIt.I<SosBloc>(),
      child: BlocListener<SosBloc, SosState>(
        listenWhen: (previo, actual) =>
            previo != actual && actual is! SosInicial,
        listener: (context, state) {
          final mensaje = switch (state) {
            SosEnviando() => 'Enviando auxilio a central...',
            SosEnviado() => 'Auxilio enviado a central',
            SosError(:final mensaje) => mensaje,
            _ => null,
          };
          if (mensaje == null) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(mensaje)));
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          bloc: GetIt.I<AuthBloc>(),
          builder: (context, state) {
            final usuario = state is AuthAutenticado ? state.usuario : null;

            return Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/menu.png',
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        _Toolbar(usuario: usuario),
                        Expanded(
                          child: usuario == null
                              ? const Center(child: CircularProgressIndicator())
                              : LayoutBuilder(
                                  builder: (context, limites) =>
                                      _MenuContenido(
                                    ancho: limites.maxWidth,
                                    alto: limites.maxHeight,
                                    usuario: usuario,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.usuario});

  final Usuario? usuario;

  Future<void> _confirmarCierre(BuildContext context) async {
    // El legacy hace `finish()` y vuelve a la pantalla de login sin matar la
    // sesion. Aca no hay pantalla de login intermedia (la guarda del router
    // rebotaria al home), asi que atras cierra sesion, con confirmacion para
    // no matarla sin querer.
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesion'),
        content: const Text('Deseas cerrar la sesion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
    if (salir == true) {
      GetIt.I<AuthBloc>().add(const AuthLogoutSolicitado());
    }
  }

  @override
  Widget build(BuildContext context) {
    final esSereno = usuario?.esSereno ?? false;
    return Container(
      height: kToolbarHeight,
      color: const Color(0x80000000), // android:background="#80000000"
      child: Row(
        children: [
          IconButton(
            tooltip: 'Atras',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _confirmarCierre(context),
          ),
          Expanded(
            child: esSereno
                ? _TituloPanelSereno(usuario: usuario!)
                : const Text(
                    'Menú Principal',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Titulo "Panel Patrulla: `<placa>`" del legacy (`MenuActivity.kt:63-65`).
///
/// La placa no viene en el login: se busca en `GET /unidades` la unidad cuyo
/// `responsableId` es el usuario en sesion. Si no tiene unidad asignada o el
/// servicio falla, se muestra "Panel Patrulla" sin placa en vez de inventarla.
class _TituloPanelSereno extends StatefulWidget {
  const _TituloPanelSereno({required this.usuario});

  final Usuario usuario;

  @override
  State<_TituloPanelSereno> createState() => _TituloPanelSerenoState();
}

class _TituloPanelSerenoState extends State<_TituloPanelSereno> {
  late final Future<String?> _placa = _buscarPlaca();

  Future<String?> _buscarPlaca() async {
    final res = await GetIt.I<ListarUnidadesUseCase>()();
    return res.fold(
      (_) => null,
      (unidades) {
        final mias =
            unidades.where((u) => u.responsableId == widget.usuario.id);
        return mias.isEmpty ? null : mias.first.placa;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _placa,
      builder: (context, snapshot) {
        final placa = snapshot.data;
        return Text(
          placa == null ? 'Panel Patrulla' : 'Panel Patrulla: $placa',
          key: const Key('titulo_panel'),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }
}

class _MenuContenido extends StatelessWidget {
  const _MenuContenido({
    required this.ancho,
    required this.alto,
    required this.usuario,
  });

  final double ancho;
  final double alto;
  final Usuario usuario;

  // Medidas identicas a activity_menu.xml (dp = logical pixels en Flutter).
  static const _wPlaca = 248.0;
  static const _hPlaca = 80.0;
  static const _wSos = 319.0;
  static const _hSos = 159.0;
  static const _wEmergencia = 248.0;
  static const _hEmergencia = 80.0;
  static const _wBoton = 200.0;
  static const _hBoton = 48.0;
  static const _hBarraRastreo = 56.0; // padding 8 + TextButton 40

  double _wLimitado(double deseado) =>
      deseado < ancho - 24 ? deseado : ancho - 24;

  double _centrado(double w) => (ancho - w) / 2;

  /// Centro vertical de un botón grafico (vertical_bias de ConstraintLayout).
  double _centro(double bias, double h) => bias * alto - h / 2;

  void _pendiente(BuildContext context, String funcion) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$funcion: funcionalidad en preparacion')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final esSereno = usuario.esSereno;

    // Anclas inferiores: la barra de rastreo toca el fondo (solo sereno); los
    // dos botones se apilan sobre ella, igual que en el XML (para los demas
    // roles la barra colapsa a un punto, como una View GONE en ConstraintLayout).
    final barra = esSereno ? _hBarraRastreo : 0.0;
    final mapaCalorTop = alto - barra - _hBoton;
    final reportarTop = mapaCalorTop - 4 - _hBoton;

    // ivAlcalde: centrado en el hueco entre btnEmergencia y la barra inferior,
    // ancho completo (wrap_content limitado por los constraints horizontales).
    final alcaldeH = ancho * 187 / 1106;
    final huecoTop = 0.723 * alto + _hEmergencia / 2;
    final alcaldeTop = (huecoTop + (alto - barra)) / 2 - alcaldeH / 2;

    final wPlaca = _wLimitado(_wPlaca);
    final wSos = _wLimitado(_wSos);
    final wEmergencia = _wLimitado(_wEmergencia);

    return Stack(
      children: [
        // Orden de pintado = orden del XML (lo declarado ultimo queda arriba):
        // placa, SOS, emergencia, alcalde, reportar, mapa de calor, rastreo.
        if (esSereno)
          Positioned(
            left: _centrado(wPlaca),
            top: _centro(0.344, _hPlaca),
            child: _BotonGrafico(
              key: const Key('menu_placa'),
              asset: 'assets/images/inplaca.png',
              etiqueta: 'Ingresar placa',
              ancho: wPlaca,
              alto: _hPlaca,
              onTap: () => _pendiente(context, 'La busqueda por placa'),
            ),
          )
        else
          BlocBuilder<SosBloc, SosState>(
            buildWhen: (previo, actual) =>
                (previo is SosEnviando) != (actual is SosEnviando),
            builder: (context, sos) => Positioned(
              left: _centrado(wSos),
              top: _centro(0.544, _hSos),
              child: _BotonGrafico(
                key: const Key('menu_sos'),
                asset: 'assets/images/ubicacion.png',
                etiqueta: 'SOS ubicacion',
                ancho: wSos,
                alto: _hSos,
                // Deshabilitado durante el envio: el SosBloc igualmente
                // ignora un toque duplicado, pero sin esto el usuario no
                // tendria forma de ver que algo esta pasando.
                onTap: sos is SosEnviando
                    ? null
                    : () => context.read<SosBloc>().add(const SosSolicitado()),
              ),
            ),
          ),
        if (!esSereno)
          Positioned(
            left: _centrado(wEmergencia),
            top: _centro(0.723, _hEmergencia),
            child: _BotonGrafico(
              key: const Key('menu_emergencia'),
              asset: 'assets/images/emergencia.png',
              etiqueta: 'Emergencia',
              ancho: wEmergencia,
              alto: _hEmergencia,
              onTap: () => context.go(Rutas.emergencias),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: alcaldeTop,
          child: Image.asset(
            'assets/images/alcalde.png',
            height: alcaldeH,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
        Positioned(
          left: _centrado(_wBoton),
          top: reportarTop,
          child: _BotonMenu(
            key: const Key('menu_reportar'),
            color: const Color(0xFFD32F2F),
            icono: Icons.image_outlined, // ic_menu_report_image
            texto: 'Reportar Incidente',
            onTap: () => context.go(Rutas.reportar),
          ),
        ),
        Positioned(
          left: _centrado(_wBoton),
          top: mapaCalorTop,
          child: _BotonMenu(
            key: const Key('menu_mapa_calor'),
            color: const Color(0xFFFF9800),
            icono: Icons.explore_outlined, // ic_menu_compass
            texto: 'Mapa de Calor',
            onTap: () => _pendiente(context, 'El mapa de calor'),
          ),
        ),
        if (esSereno)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              key: const Key('menu_rastreo'),
              color: const Color(0x80000000),
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 40,
                    child: TextButton(
                      key: const Key('menu_iniciar_rastreo'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _pendiente(context, 'El rastreo'),
                      child: const Text('Iniciar Rastreo'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 40,
                    child: TextButton(
                      key: const Key('menu_ver_mapa'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFFEB3B),
                        textStyle: const TextStyle(fontSize: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => context.go(Rutas.mapa),
                      child: const Text('Ver Mapa'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 40,
                    child: TextButton(
                      key: const Key('menu_detener_rastreo'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF4444), // holo_red_light
                        textStyle: const TextStyle(fontSize: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _pendiente(context, 'El rastreo'),
                      child: const Text('Detener'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Botón grafico del menu (ImageView con src del legacy, fitCenter).
class _BotonGrafico extends StatelessWidget {
  const _BotonGrafico({
    super.key,
    required this.asset,
    required this.etiqueta,
    required this.ancho,
    required this.alto,
    required this.onTap,
  });

  final String asset;
  final String etiqueta;
  final double ancho;
  final double alto;

  /// `null` mientras el envio de SOS esta en curso: el boton conserva su
  /// apariencia exacta y simplemente no responde al toque.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiqueta,
      child: InkWell(
        onTap: onTap,
        child: Image.asset(
          asset,
          width: ancho,
          height: alto,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

/// Button del legacy: 200x48dp, texto 14sp blanco, backgroundTint propio.
class _BotonMenu extends StatelessWidget {
  const _BotonMenu({
    super.key,
    required this.color,
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final Color color;
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 14),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: onTap,
        icon: Icon(icono, size: 18),
        label: Text(texto, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
