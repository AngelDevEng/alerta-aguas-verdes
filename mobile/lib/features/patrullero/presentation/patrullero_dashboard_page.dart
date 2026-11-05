import 'package:flutter/material.dart';

class PatrulleroDashboardPage extends StatelessWidget {
  const PatrulleroDashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel patrullero')),
      body: const Center(child: Text('Alertas activas (polling 10s) - en implementacion')),
    );
  }
}
