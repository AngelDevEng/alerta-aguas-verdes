import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/unidad.dart';
import '../../domain/usecases/unidad_usecases.dart';

class BuscarPlacaPage extends StatefulWidget {
  const BuscarPlacaPage({super.key});

  @override
  State<BuscarPlacaPage> createState() => _BuscarPlacaPageState();
}

class _BuscarPlacaPageState extends State<BuscarPlacaPage> {
  final _controlador = TextEditingController();
  List<Unidad>? _resultados;
  String? _error;
  bool _cargando = false;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final placa = _controlador.text.trim();
    if (placa.isEmpty) {
      setState(() => _error = 'Ingresa una placa.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
      _resultados = null;
    });
    final caso = GetIt.I<BuscarUnidadPorPlacaUseCase>();
    final r = await caso(placa);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      switch (r) {
        case Ok<List<Unidad>>(:final value):
          _resultados = value;
        case Err<List<Unidad>>(:final failure):
          _error = failure.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar por placa')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controlador,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Placa...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _cargando ? null : _buscar,
                  child: const Text('BUSCAR'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_cargando) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_resultados != null) ...[
              if (_resultados!.isEmpty)
                const Text('No se encontraron unidades con esa placa.')
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _resultados!.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, i) {
                      final u = _resultados![i];
                      return ListTile(
                        leading: const Icon(Icons.local_police),
                        title: Text(u.etiquetaOperador),
                        subtitle: Text(
                          '${u.tipo.etiqueta} · ${u.estado.etiqueta}',
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}