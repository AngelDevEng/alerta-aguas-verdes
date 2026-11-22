import 'package:alerta_aguas_verdes/core/maps/map_tiles.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mensajeErrorTile', () {
    test('no expone la key de MapTiler ni el query string', () {
      const secreta = 'SECRET_KEY_123';
      final error = NetworkImageLoadException(
        statusCode: 403,
        uri: Uri.parse(
          'https://api.maptiler.com/maps/streets/256/12/34/56.png?key=$secreta',
        ),
      );

      final msg = mensajeErrorTile(12, 34, 56, error);

      expect(msg, contains('status=403'));
      expect(msg, contains('/maps/streets/256/12/34/56.png'));
      expect(msg, isNot(contains(secreta)));
      expect(msg, isNot(contains('key=')));
      expect(msg, isNot(contains('?')));
    });

    test('otros errores no imprimen la URL', () {
      final msg = mensajeErrorTile(1, 2, 3, StateError('boom'));

      expect(msg, contains('z1/2/3'));
      expect(msg, contains('StateError'));
      expect(msg, isNot(contains('http')));
    });
  });
}