import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/incidencia.dart';
import '../bloc/incidencias_state.dart';

/// Hoja modal con los filtros de la lista.
///
/// Vive en un bottom sheet y no en la pantalla para no stealar altura: la lista
/// de incidencias es lo que el operador mira el 90% del tiempo, y los filtros
/// se cambian pocas veces.
class FiltrosSheet extends StatefulWidget {
  const FiltrosSheet({
    super.key,
    required this.filtros,
    required this.tipos,
  });

  final FiltrosIncidencia filtros;
  final List<TipoFiltro> tipos;

  @override
  State<FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends State<FiltrosSheet> {
  late EstadoIncidencia? _estado = widget.filtros.estado;
  late int? _tipoId = widget.filtros.tipoId;
  late DateTime? _desde = widget.filtros.desde;
  late DateTime? _hasta = widget.filtros.hasta;

  bool get _hayAlguno =>
      _estado != null || _tipoId != null || _desde != null || _hasta != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Filtros', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),

            _etiqueta('Estado'),
            DropdownButtonFormField<EstadoIncidencia?>(
              initialValue: _estado,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                // `unknown` no se ofrece: es un valor defensivo del parseo, no
                // un estado que el operador pueda querer filtrar.
                for (final e in EstadoIncidencia.values.where((e) => e != EstadoIncidencia.unknown))
                  DropdownMenuItem(value: e, child: Text(e.etiqueta)),
              ],
              onChanged: (v) => setState(() => _estado = v),
            ),
            const SizedBox(height: 14),

            _etiqueta('Tipo'),
            // Sin endpoint de tipos, la lista sale de lo ya cargado: si todavia no hay
            // datos no hay nada que filtrar por tipo, y se lo dice al usuario
            // en vez de mostrar un desplegable vacio sin explicacion.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int?>(
                  initialValue: _tipoId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    for (final t in widget.tipos)
                      DropdownMenuItem(value: t.id, child: Text(t.nombre)),
                  ],
                  onChanged: widget.tipos.isEmpty
                      ? null
                      : (v) => setState(() => _tipoId = v),
                ),
                if (widget.tipos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Se completa al cargar incidencias.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            _etiqueta('Ocurrio entre'),
            Row(
              children: [
                Expanded(
                  child: _BotonFecha(
                    etiqueta: 'Desde',
                    valor: _desde,
                    onChanged: (v) => setState(() => _desde = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BotonFecha(
                    etiqueta: 'Hasta',
                    valor: _hasta,
                    onChanged: (v) => setState(() => _hasta = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                if (_hayAlguno)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _estado = null;
                          _tipoId = null;
                          _desde = null;
                          _hasta = null;
                        });
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Limpiar'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                if (_hayAlguno) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      FiltrosIncidencia(
                        estado: _estado,
                        tipoId: _tipoId,
                        desde: _desde,
                        hasta: _hasta,
                      ),
                    ),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _etiqueta(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _BotonFecha extends StatelessWidget {
  const _BotonFecha({
    required this.etiqueta,
    required this.valor,
    required this.onChanged,
  });

  final String etiqueta;
  final DateTime? valor;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final texto = valor == null ? etiqueta : fmt.format(valor!);

    return OutlinedButton.icon(
      onPressed: () async {
        final ahora = DateTime.now();
        final elegido = await showDatePicker(
          context: context,
          initialDate: valor ?? ahora,
          firstDate: DateTime(ahora.year - 5),
          lastDate: DateTime(ahora.year + 1),
        );
        if (elegido != null) onChanged(elegido);
      },
      icon: Icon(Icons.calendar_today_outlined, size: 16),
      label: Text(
        texto,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}