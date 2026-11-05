import 'dart:async';
import 'package:flutter/material.dart';

class PatrulleroDashboardPage extends StatefulWidget {
  const PatrulleroDashboardPage({super.key});
  @override
  State<PatrulleroDashboardPage> createState() => _PatrulleroDashboardPageState();
}

class _PatrulleroDashboardPageState extends State<PatrulleroDashboardPage> {
  Timer? _timer;
  final List<Map<String, dynamic>> _alertas = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    // TODO: llamar a GET /alertas/activas con token del usuario autenticado
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel patrullero')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _alertas.length,
              itemBuilder: (ctx, i) => ListTile(title: Text(_alertas[i].toString())),
            ),
    );
  }
}
