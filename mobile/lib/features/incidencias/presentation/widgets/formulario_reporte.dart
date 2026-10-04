import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/location/location_service.dart';
import '../../domain/entities/incidencia.dart';
import '../../domain/entities/tipo_incidencia.dart';
import '../bloc/reportar_state.dart';
import 'aviso_fotos_pendientes.dart';
import 'selector_fotos.dart';
import 'tarjeta_ubicacion.dart';

/// Formulario de reporte de incidencia, sin la logica de envio.
///
/// La pagina conserva el estado (tipo, fotos, posicion) y le pasa callbacks:
/// este widget pinta y valida, pero no sabe nada de BLoC. Que el `Form` y los
/// controladores vivan afuera es lo que permite reenviar el formulario sin
/// perder lo escrito cuando falla la subida de fotos.
class FormularioReporte extends StatelessWidget {
  const FormularioReporte({
    super.key,
    required this.formKey,
    required this.descripcion,
    required this.referencia,
    required this.tipo,
    required this.prioridad,
    required this.fotos,
    required this.posicion,
    required this.ubicando,
    required this.exitoPrevio,
    required this.onTipo,
    required this.onPrioridad,
    required this.onUbicacion,
    required this.onCamara,
    required this.onGaleria,
    required this.onQuitarFoto,
    required this.onReintentarFotos,
    required this.lugarDe,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController descripcion;
  final TextEditingController referencia;
  final TipoIncidencia? tipo;
  final Prioridad? prioridad;
  final List<XFile> fotos;
  final PosicionActual? posicion;
  final bool ubicando;
  final ReportarExito? exitoPrevio;
  final ValueChanged<TipoIncidencia?> onTipo;
  final ValueChanged<Prioridad?> onPrioridad;
  final VoidCallback onUbicacion;
  final VoidCallback onCamara;
  final VoidCallback onGaleria;
  final ValueChanged<int> onQuitarFoto;
  final VoidCallback onReintentarFotos;
  final Future<String> Function(PosicionActual) lugarDe;

  /// Traduce la [prioridad] elegida a la opcion del desplegable.
  ///
  /// Si el tipo no tiene sugerencia visible se muestra igual "La del tipo": el
  /// usuario puede forzar una prioridad concreta sin que el campo se resetee.
  OpcionPrioridad get _prioridadActual => opcionesPrioridad.firstWhere(
        (o) => o.valor == prioridad,
        orElse: () => opcionesPrioridad.first,
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (exitoPrevio?.parcial == true) ...[
            AvisoFotosPendientes(exito: exitoPrevio!, onReintentar: onReintentarFotos),
            const SizedBox(height: 16),
          ],

          const EtiquetaCampo('Tipo de incidencia'),
          DropdownButtonFormField<TipoIncidencia>(
            initialValue: tipo,
            isExpanded: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
            items: [
              for (final t in TiposIncidencia.porDefecto)
                DropdownMenuItem(
                  value: t,
                  child: Text(t.nombre, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onTipo,
          ),
          const SizedBox(height: 16),

          const EtiquetaCampo('Descripción'),
          TextFormField(
            controller: descripcion,
            maxLines: 4,
            minLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Que esta pasando, donde y cuando.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),

          const EtiquetaCampo('Prioridad'),
          // El desplegable usa [OpcionPrioridad] y no `Prioridad?`: un
          // `DropdownButtonFormField` con tipo anulable y un item de valor null
          // es fragil (Flutter compara el valor contra los items para marcar
          // el seleccionado). Con una clase propia, "segun el tipo" es un valor
          // mas y el dominio [Prioridad] no se ensucia con una opcion de UI.
          DropdownButtonFormField<OpcionPrioridad>(
            initialValue: _prioridadActual,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.priority_high),
              helperText: 'Por defecto se usa la del tipo elegido',
            ),
            items: [
              for (final o in opcionesPrioridad)
                DropdownMenuItem(
                  value: o,
                  child: Text(o.etiqueta),
                ),
            ],
            onChanged: (o) => onPrioridad(o?.valor),
          ),
          const SizedBox(height: 16),

          const EtiquetaCampo('Referencia (opcional)'),
          TextFormField(
            controller: referencia,
            maxLength: NuevaIncidencia.maxReferencia,
            decoration: const InputDecoration(
              hintText: 'Patente, numero de expediente, nombre del local',
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: 8),

          const EtiquetaCampo('Ubicación'),
          TarjetaUbicacion(
            posicion: posicion,
            ubicando: ubicando,
            onActualizar: onUbicacion,
            lugarDe: lugarDe,
          ),
          const SizedBox(height: 16),

          const EtiquetaCampo('Fotos (opcional)'),
          SelectorFotos(
            fotos: fotos,
            onCamara: onCamara,
            onGaleria: onGaleria,
            onQuitar: onQuitarFoto,
          ),
        ],
      ),
    );
  }
}

/// Opcion del desplegable de prioridad.
///
/// Envoltura de [Prioridad] para poder ofrecer "segun el tipo" sin meter un
/// `null` en el `DropdownButton` ni un miembro artificial en el enum del dominio.
@immutable
class OpcionPrioridad {
  const OpcionPrioridad(this.valor, this.etiqueta);

  /// `null` significa "que el servidor use la prioridad del tipo".
  final Prioridad? valor;
  final String etiqueta;
}

const opcionesPrioridad = <OpcionPrioridad>[
  OpcionPrioridad(null, 'La del tipo'),
  OpcionPrioridad(Prioridad.baja, 'Baja'),
  OpcionPrioridad(Prioridad.media, 'Media'),
  OpcionPrioridad(Prioridad.alta, 'Alta'),
  OpcionPrioridad(Prioridad.critica, 'Critica'),
];

/// Rotulo de un campo del formulario.
class EtiquetaCampo extends StatelessWidget {
  const EtiquetaCampo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
