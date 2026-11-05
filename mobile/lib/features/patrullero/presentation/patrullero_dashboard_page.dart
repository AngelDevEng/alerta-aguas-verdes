import 'package:flutter/material.dart';
import '../../../core/realtime/socket_service.dart';

class PatrulleroDashboardPage extends StatefulWidget {
  const PatrulleroDashboardPage({super.key, required this.socketService});
  final SocketService socketService;

  @override
  State<PatrulleroDashboardPage> createState() => _PatrulleroDashboardPageState();
}

class _PatrulleroDashboardPageState extends State<PatrulleroDashboardPage> {
  final List<Map<String, dynamic>> _alertas = [];

  @override
  void initState() {
    super.initState();
    widget.socketService.positions.listen((data) {
      setState(() => _alertas.insert(0, data));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel patrullero (tiempo real)')),
      body: ListView.builder(
        itemCount: _alertas.length,
        itemBuilder: (ctx, i) => ListTile(title: Text(_alertas[i].toString())),
      ),
    );
  }
}
