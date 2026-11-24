import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/sos_session_store.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../alertas/presentation/bloc/sos_bloc.dart';
import '../../../alertas/presentation/bloc/sos_event.dart';
import '../../../alertas/presentation/bloc/sos_state.dart';
import '../../../rastreo/presentation/rastreo_ciudadano_page.dart';
import '../../../catalogos/presentation/bloc/catalogos_bloc.dart';
import '../../../catalogos/presentation/bloc/catalogos_event.dart';
import '../../../catalogos/presentation/bloc/catalogos_state.dart';
import '../../../unidades/presentation/pages/buscar_placa_page.dart';

/// Home: launcher de panico, 1:1 con `Activity_Panico_Main` +
/// `activity_panico_main.xml` del legacy Java (referencia canonica desde
/// 2026-10-07, ver `docs/paridad.md`).
///
/// Reproduce el layout original:
/// - fondo gradiente `bg_gradient_celeste` (#ADC8E8 -> #FFFFFF, angle 270),
/// - header: escudo 70x80 + "ALERTA" 54sp `#1B1B45` + logomuni + "AGUAS
///   VERDES" 34sp `#2E7D32` (`activity_panico_main.xml:8-69`),
/// - boton SOS circular de 290dp (`:71-91`), conectado: GPS + `POST /alertas`
///   (4d.2),
/// - grid 2x2 de tarjetas blancas (radio 16, elevacion 2, icono + rotulo 16sp
///   bold negro): POLICIA PNP, SERENAZGO, INCIDENTES, EMERGENCIAS MULtiples
///   (`:93-266`),
/// - footer blanco de 70dp con "Buscar:" + campo Placa... + boton BUSCAR
///   `#0A6C9C` (`:268-313`).
///
/// Acciones (el legacy marca/llama, nosotros navegamos o llamamos igual):
/// - POLICIA PNP / SERENAZGO: llamada `tel:` con el contacto de
///   `GET /catalogos/emergencias`; si el catalogo no esta listo se usan los
///   defaults que el legacy guarda en SharedPreferences "CENTRAL"
///   (`Activity_Panico_Main.java:178-182`).
/// - INCIDENTES -> reportar incidencia; EMERGENCIAS MULtiples -> central de
///   emergencias (equivale a `Activity_Emergencias_Grid`).
/// - BUSCAR: la pantalla `Activity_Buscar_Placa` aun no existe en Flutter
///   (paridad fila 6) -> mismo aviso de "en preparacion" del menu anterior.
///
/// Divergencias documentadas:
/// - En el legacy, el patrullero y el admin aterrizan en su dashboard
///   (`Activity_Login.java:164-238`) y este launcher es del ciudadano. Como
///   `Activity_Patrullero_Dashboard` y `MainActivity` todavia no existen en
///   Flutter (paridad filas 3 y 9), todos los roles aterrizan aqui.
/// - El tap del escudo es el equivalente provisional de `admin()`
///   (`Activity_Panico_Main.java:209-227`): abre la accion de sesion mientras
///   no existan esas pantallas.
/// - El pulso `anim/pulse.xml` del logomuni no se replica: una animacion
///   infinita colgaria `pumpAndSettle` de los tests sin aportar funcion.
/// - Tras el SOS el legacy abre `Activity_Rastreo` y arranca
///   `CiudadanoTrackingService`; eso es paridad 4d.4 (aun pendiente).
/// - La barra de rastreo/panel patrulla del menu del viejo legacy Kotlin no
///   existia en este launcher: se quito por 1:1 estricto.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // `.value` a proposito: el SosBloc es un singleton de aplicacion. Si se
        // creara con `create`, al desmontar el home se cerraria el bloc y se
        // perderian los reintentos de un SOS pendiente.
        BlocProvider<SosBloc>.value(value: GetIt.I<SosBloc>()),
        BlocProvider<CatalogosBloc>(
          create: (_) =>
              GetIt.I<CatalogosBloc>()..add(const CargarEmergencias()),
        ),
      ],
      child: BlocListener<SosBloc, SosState>(
        listenWhen: (previo, actual) =>
            previo != actual && actual is! SosInicial,
        listener: (context, state) async {
          if (state is SosEnviado) {
            final alertaId = state.alertaId;
            final sessionToken = state.sessionToken;
            if (alertaId.isNotEmpty && sessionToken != null) {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RastreoCiudadanoPage(
                  alertaId: alertaId,
                  sessionToken: sessionToken,
                ),
              ));
            }
            if (context.mounted) _snack(context, 'Auxilio enviado a central');
            return;
          }

          if (state is SosFinalizada) {
            _snack(context, 'Tu alerta ya fue atendida por serenazgo.');
          }
        },
        child: const _LanzadorPanico(),
      ),
    );
  }
}

class _LanzadorPanico extends StatelessWidget {
  const _LanzadorPanico();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // bg_gradient_celeste.xml: start #ADC8E8, end #FFFFFF, angle 270.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFADC8E8), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Encabezado(onEscudo: () => _accionesSesion(context)),
              // Banner persistente del estado del SOS: "Conectando con la
              // central..." mientras reintenta, o el error con "Llamar ahora".
              const _SosBanner(),
              // El legacy reparte header/SOS/grid con constraints fijas; aca
              // el SOS queda Flexible y la grilla con alto proporcional para
              // que ninguna pantalla desborde (los dp del XML son fijos y en
              // celos chicas se solaparian).
              Expanded(
                child: LayoutBuilder(
                  builder: (context, limites) {
                    final altoGrilla =
                        (limites.maxHeight * 0.44).clamp(150.0, 300.0);
                    return Column(
                      children: [
                        const Expanded(child: _SeccionSos()),
                        SizedBox(
                          height: altoGrilla,
                          child: const _Cuadricula(),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const _PieBusqueda(),
              const _SosReanudarBoton(),
              const _PanelOperadorBoton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header: escudo + "ALERTA" + logomuni + "AGUAS VERDES".
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.onEscudo});

  final VoidCallback onEscudo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Sesion',
            child: InkWell(
              key: const Key('home_escudo'),
              onTap: onEscudo,
              child: Image.asset(
                'assets/images/escudo.webp',
                width: 70,
                height: 80,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FittedBox: si el titulo no entra en pantallas angostas,
                // escala en vez de desbordar (el XML no prevee esto).
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ALERTA',
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B1B45),
                          height: 1,
                          // includeFontPadding: false del XML.
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Image.asset(
                          'assets/images/logomuni.png',
                          width: 50,
                          height: 50,
                          gaplessPlayback: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'AGUAS VERDES',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                    height: 1,
                    leadingDistribution: TextLeadingDistribution.even,
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

/// Boton SOS de 290dp (`btnsos.webp`), deshabilitado mientras envia.
class _SeccionSos extends StatelessWidget {
  const _SeccionSos();

  @override
  Widget build(BuildContext context) {
    final authState = GetIt.I.isRegistered<AuthBloc>() ? GetIt.I<AuthBloc>().state : null;
    final sesionOperativa = authState is AuthAutenticado;
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: BlocBuilder<SosBloc, SosState>(
          buildWhen: (previo, actual) =>
              previo.runtimeType != actual.runtimeType,
          builder: (context, sos) {
            final ocupado = sos is SosEnviando || sos is SosConectandoCentral;
            final activa = sos is SosEnviado;
            final bloqueado = sesionOperativa;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: bloqueado
                      ? 'SOS disponible solo para ciudadanos sin sesion'
                      : activa
                          ? 'Ver mi alerta activa'
                          : 'SOS ubicacion',
                  child: InkWell(
                    key: const Key('menu_sos'),
                    customBorder: const CircleBorder(),
                    onTap: ocupado || bloqueado
                        ? null
                        : activa
                            ? () => _abrirRastreoActivo(context, sos)
                            : () => context.read<SosBloc>().add(const SosSolicitado()),
                    child: Opacity(
                      opacity: (activa || bloqueado) ? 0.55 : 1,
                      child: Image.asset(
                        'assets/images/btnsos.webp',
                        width: 290,
                        height: 290,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
                if (bloqueado)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'SOS disponible solo para ciudadanos',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (activa && !bloqueado)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.icon(
                      key: const Key('menu_ver_alerta_activa'),
                      onPressed: () => _abrirRastreoActivo(context, sos),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Ver mi alerta activa'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _abrirRastreoActivo(BuildContext context, SosEnviado sos) async {
    final token = sos.sessionToken;
    if (token == null || token.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RastreoCiudadanoPage(
        alertaId: sos.alertaId,
        sessionToken: token,
      ),
    ));
    if (context.mounted) {
      context.findAncestorStateOfType<SosReanudarBotonState>()?._cargar();
    }
  }
}

/// Banner persistente con el estado del envio de SOS.
///
/// Reemplaza el snackbar para los estados que exigen atencion sostenida: si la
/// central no responde, el usuario ve "Conectando con la central..." sin que
/// desaparezca; si el envio falla de forma definitiva, ve el error y un boton
/// "Llamar ahora" al serenazgo.
class _SosBanner extends StatelessWidget {
  const _SosBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SosBloc, SosState>(
      buildWhen: (previo, actual) {
        if (previo is SosError && actual is SosError) {
          return previo.mensaje != actual.mensaje;
        }
        return previo.runtimeType != actual.runtimeType;
      },
      builder: (context, state) {
        return switch (state) {
          SosEnviando() => _banner(
              color: const Color(0xFF0A6C9C),
              icono: Icons.send_rounded,
              texto: 'Enviando auxilio a central...',
              botones: [
                _BotonBanner(
                  texto: 'Cancelar envío',
                  color: const Color(0xFF0A6C9C),
                  onPressed: () => context.read<SosBloc>().add(
                        const SosCancelarEnvio(),
                      ),
                ),
                // Si la central no responde en 5 s, el usuario necesita el
                // telefono sin esperar a que se agote el timeout de la peticion.
                const _LlamarAhoraTardio(),
              ],
            ),
          SosConectandoCentral() => _banner(
              color: const Color(0xFFB26A00),
              icono: Icons.wifi_tethering_rounded,
              texto: 'Conectando con la central...',
              botones: [
                _BotonBanner(
                  texto: 'Cancelar envío',
                  color: const Color(0xFFB26A00),
                  onPressed: () => context.read<SosBloc>().add(
                        const SosCancelarEnvio(),
                      ),
                ),
              ],
            ),
          SosError(:final mensaje) => _banner(
              color: const Color(0xFFB3261E),
              icono: Icons.warning_amber_rounded,
              texto: mensaje,
              botones: [
                _BotonBanner(
                  texto: 'Llamar ahora',
                  onPressed: _llamarCentral,
                ),
              ],
            ),
          SosCancelado() => _banner(
              color: const Color(0xFF5F6368),
              icono: Icons.stop_circle_outlined,
              texto:
                  'Se detuvo el envío. Si la central ya recibió tu alerta, '
                  'podrá contactarte.',
              botones: [
                _BotonBanner(
                  texto: 'Reintentar',
                  color: const Color(0xFF5F6368),
                  onPressed: () => context.read<SosBloc>().add(
                        const SosSolicitado(),
                      ),
                ),
                _BotonBanner(
                  texto: 'Llamar ahora',
                  color: const Color(0xFF5F6368),
                  onPressed: _llamarCentral,
                ),
              ],
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

Widget _banner({
  required Color color,
  required IconData icono,
  required String texto,
  List<Widget> botones = const [],
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icono, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.2,
            ),
          ),
        ),
        ...botones,
      ],
    ),
  );
}

class _BotonBanner extends StatelessWidget {
  const _BotonBanner({
    required this.texto,
    required this.onPressed,
    this.color = const Color(0xFFB3261E),
  });

  final String texto;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            texto,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Boton "Llamar ahora" que aparece si el envio sigue en curso tras 5 s.
///
/// Mientras la peticion esta en vuelo el usuario no tiene el telefono a mano;
/// si la central no responde, esperar al timeout (8 s) es demasiado. Este
/// widget arranca su propio temporizador al montarse y lo cancela al desmontar,
/// asi que el boton solo se muestra en envios que realmente se alargan.
class _LlamarAhoraTardio extends StatefulWidget {
  const _LlamarAhoraTardio();

  @override
  State<_LlamarAhoraTardio> createState() => _LlamarAhoraTardioState();
}

class _LlamarAhoraTardioState extends State<_LlamarAhoraTardio> {
  static const _umbral = Duration(seconds: 5);

  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_umbral, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return _BotonBanner(texto: 'Llamar ahora', onPressed: _llamarCentral);
  }
}

/// Llama al serenazgo desde el banner de error del SOS.
void _llamarCentral() {
  launchUrl(
    Uri.parse('tel:${Env.emergencyPhone}'),
    mode: LaunchMode.externalApplication,
  );
}

/// Grilla 2x2 de tarjetas del XML (`:93-266`).
class _Cuadricula extends StatelessWidget {
  const _Cuadricula();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _Tarjeta(
                    key: const Key('menu_comisaria'),
                    icono: 'assets/images/ic_comisaria.webp',
                    rotulo: 'POLICIA PNP',
                    onTap: () => _llamar(context, comisaria: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Tarjeta(
                    key: const Key('menu_serenazgo'),
                    icono: 'assets/images/ic_serenazgo.webp',
                    rotulo: 'SERENAZGO',
                    onTap: () => _llamar(context, comisaria: false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _Tarjeta(
                    key: const Key('menu_incidencias'),
                    icono: 'assets/images/ic_incidencia.webp',
                    rotulo: 'INCIDENTES',
                    onTap: () => context.go(Rutas.reportar),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Tarjeta(
                    key: const Key('menu_mapa_calor'),
                    icono: 'assets/images/ic_incidencia.webp',
                    rotulo: 'MAPA\nDELITOS',
                    onTap: () => context.go(Rutas.mapaCalor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Tarjeta(
                    key: const Key('menu_otras_emergencias'),
                    icono: 'assets/images/ic_otras_emergencias.webp',
                    rotulo: 'EMERGENCIAS\nMÚLTIPLES',
                    onTap: () => context.go(Rutas.emergencias),
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

/// Card blanca 16dp/elevacion 2 con icono arrotulado (XML `:108-144`).
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    super.key,
    required this.icono,
    required this.rotulo,
    required this.onTap,
  });

  final String icono;
  final String rotulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: Image.asset(
                  icono,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rotulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer de busqueda de placa (`:268-313`).
class _PieBusqueda extends StatefulWidget {
  const _PieBusqueda();

  @override
  State<_PieBusqueda> createState() => _PieBusquedaState();
}

class _PieBusquedaState extends State<_PieBusqueda> {
  final TextEditingController _controlador = TextEditingController();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Text(
            'Buscar:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const Key('placa_input'),
              controller: _controlador,
              // android:inputType="textCapCharacters".
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
              decoration: const InputDecoration(
                hintText: 'Placa...',
                hintStyle: TextStyle(fontSize: 16, color: Color(0xFF333333)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Buscar placa',
            child: InkWell(
              key: const Key('menu_buscar'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BuscarPlacaPage()),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF0A6C9C),
                child: const Text(
                  'BUSCAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Llamada directa a policia/serenazgo, igual que el legacy.
///
/// El legacy lee el numero de SharedPreferences "CENTRAL" (sincronizada con
/// `obtener_numeros.php`) y, si no hay, usa defaults `980121632` (policia) y
/// `072601494` (serenazgo) (`Activity_Panico_Main.java:178-182`). Aqui: el
/// contacto del catalogo que cargo este mismo widget; si no esta listo o no
/// coincide, el mismo default legacy.
void _llamar(BuildContext context, {required bool comisaria}) {
  String telefono = comisaria ? '980121632' : '072601494';
  final estado = context.read<CatalogosBloc>().state;
  if (estado is CatalogosListos) {
    for (final c in estado.emergencias) {
      if (c.esWhatsapp) continue;
      final nombre = c.nombre.toUpperCase();
      final coincide =
          comisaria ? nombre.contains('COMISAR') : nombre == 'SERENAZGO';
      if (coincide) {
        telefono = c.telefonoInternacional;
        break;
      }
    }
  }
  launchUrl(
    Uri.parse('tel:$telefono'),
    mode: LaunchMode.externalApplication,
  );
}

/// Accion del escudo: abre opciones de sesion solo cuando el usuario lo pide.
/// La sesion no se cierra por navegar o retroceder; solo por cierre explicito
/// o por la expiracion/invalidacion del token.
Future<void> _accionesSesion(BuildContext context) async {
  if (!GetIt.I.isRegistered<AuthBloc>()) {
    context.go(Rutas.login);
    return;
  }
  final estado = GetIt.I<AuthBloc>().state;
  if (estado is! AuthAutenticado) {
    context.go(Rutas.login);
    return;
  }
  final cerrar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sesion'),
      content: Text(estado.usuario.nombreCompleto),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Cerrar sesion'),
        ),
      ],
    ),
  );
  if (cerrar == true && context.mounted) {
    GetIt.I<AuthBloc>().add(const AuthLogoutSolicitado());
  }
}

/// Aviso de funcion pendiente (mismo texto del menu anterior).
void _snack(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

/// Boton que lleva al dashboard del patrullero. Solo visible para roles
/// operativos (SERENO/OPERADOR/ADMIN/DIRECTIVO); el ciudadano no lo ve.
class _PanelOperadorBoton extends StatelessWidget {
  const _PanelOperadorBoton();

  @override
  Widget build(BuildContext context) {
    if (!GetIt.I.isRegistered<AuthBloc>()) return const SizedBox.shrink();
    return BlocProvider<AuthBloc>.value(
      value: GetIt.I<AuthBloc>(),
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAutenticado) return const SizedBox.shrink();
          final u = state.usuario;
          if (u.esCiudadano || u.rol == 'SERENO') return const SizedBox.shrink();
          return TextButton(
            onPressed: () => context.go(Rutas.patrullero),
            child: const Text('Panel operador (alertas activas)'),
          );
        },
      ),
    );
  }
}

  /// Reanuda el seguimiento si el ciudadano ya tenia una SOS activa guardada.
  ///
  /// Se refresca al montar, al cambiar el estado del SosBloc y al volver de la
  /// pantalla de rastreo. Si la sesion ya no existe, se oculta.
class _SosReanudarBoton extends StatefulWidget {
  const _SosReanudarBoton();

  @override
  State<_SosReanudarBoton> createState() => SosReanudarBotonState();
}

class SosReanudarBotonState extends State<_SosReanudarBoton> {
    bool _haySesion = false;
  
    @override
    void initState() {
      super.initState();
      _cargar();
    }
  
    Future<void> _cargar() async {
      if (!GetIt.I.isRegistered<SosSessionStore>()) return;
      try {
        final sesion = await GetIt.I<SosSessionStore>().read();
        if (!mounted) return;
        setState(() => _haySesion = sesion != null);
      } catch (_) {}
    }
  
    Future<void> _abrir() async {
      if (!GetIt.I.isRegistered<SosSessionStore>()) return;
      try {
        final sesion = await GetIt.I<SosSessionStore>().read();
        if (sesion == null || !mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RastreoCiudadanoPage(
            alertaId: sesion.alertaId,
            sessionToken: sesion.sessionToken,
          ),
        ));
        await _cargar();
      } catch (_) {}
    }
  
    @override
    Widget build(BuildContext context) {
      return BlocListener<SosBloc, SosState>(
        listenWhen: (_, actual) =>
            actual is SosEnviado || actual is SosFinalizada || actual is SosInicial || actual is SosCancelado,
        listener: (_, __) => _cargar(),
        child: !_haySesion
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('menu_reanudar_sos'),
                    onPressed: _abrir,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Ver mi alerta activa'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0A6C9C),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
      );
    }
  }
