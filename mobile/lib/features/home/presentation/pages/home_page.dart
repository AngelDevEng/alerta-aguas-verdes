import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../alertas/presentation/bloc/sos_bloc.dart';
import '../../../alertas/presentation/bloc/sos_event.dart';
import '../../../alertas/presentation/bloc/sos_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../catalogos/presentation/bloc/catalogos_bloc.dart';
import '../../../catalogos/presentation/bloc/catalogos_event.dart';
import '../../../catalogos/presentation/bloc/catalogos_state.dart';

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
        BlocProvider<SosBloc>(create: (_) => GetIt.I<SosBloc>()),
        BlocProvider<CatalogosBloc>(
          create: (_) =>
              GetIt.I<CatalogosBloc>()..add(const CargarEmergencias()),
        ),
      ],
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
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: BlocBuilder<SosBloc, SosState>(
          buildWhen: (previo, actual) =>
              (previo is SosEnviando) != (actual is SosEnviando),
          builder: (context, sos) {
            final enviando = sos is SosEnviando;
            return Semantics(
              button: true,
              label: 'SOS ubicacion',
              child: InkWell(
                key: const Key('menu_sos'),
                customBorder: const CircleBorder(),
                // Mientras envia, el SosBloc igual ignora un toque duplicado;
                // sin esto el usuario no veria que algo esta pasando.
                onTap: enviando
                    ? null
                    : () => context.read<SosBloc>().add(const SosSolicitado()),
                child: Image.asset(
                  'assets/images/btnsos.webp',
                  width: 290,
                  height: 290,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
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
              // La pantalla de resultados (Activity_Buscar_Placa) es la fila
              // 6 de la matriz de paridad: todavia no existe.
              onTap: () => _pendiente(context, 'La busqueda por placa'),
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

/// Accion del escudo: stand-in de `admin()` del legacy
/// (`Activity_Panico_Main.java:209-227`), que llevaba a
/// Dashboard/MainActivity/Login segun rol. Esas pantallas aun no existen
/// (paridad filas 3 y 9), asi que mientras expone la unica accion de sesion.
Future<void> _accionesSesion(BuildContext context) async {
  final accion = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesion'),
            onTap: () => Navigator.of(context).pop('salir'),
          ),
        ],
      ),
    ),
  );
  if (accion == 'salir' && context.mounted) {
    await _confirmarCierre(context);
  }
}

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

/// Aviso de funcion pendiente (mismo texto del menu anterior).
void _pendiente(BuildContext context, String funcion) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$funcion: funcionalidad en preparacion')));
}
