import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injector.dart';
import 'core/maps/map_tiles.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  // Fija el directorio de caché de tiles versionado antes de crear el mapa.
  await MapTiles.init();
  runApp(const App());
}