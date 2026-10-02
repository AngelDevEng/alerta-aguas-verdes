import 'package:alerta_aguas_verdes/features/catalogos/data/models/catalogos_dto.dart';
import 'package:alerta_aguas_verdes/features/catalogos/domain/entities/catalogo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContactoEmergenciaDto.fromJson', () {
    test('mapea el camelCase que devuelve NestJS', () {
      final dto = ContactoEmergenciaDto.fromJson({
        'id': 5,
        'nombre': 'Bomberos',
        'telefono': '51972561385',
        'esWhatsapp': false,
        'orden': 3,
      });

      expect(dto.id, 5);
      expect(dto.nombre, 'Bomberos');
      expect(dto.esWhatsapp, isFalse);
      expect(dto.orden, 3);
      expect(dto.activo, isTrue);
    });

    test('acepta es_whatsapp en snake_case como fallback', () {
      final dto = ContactoEmergenciaDto.fromJson({
        'id': 6,
        'nombre': 'Serenazgo',
        'telefono': '51967404172',
        'es_whatsapp': true,
        'orden': 6,
      });

      expect(dto.esWhatsapp, isTrue);
    });

    test('no falla si faltan campos opcionales', () {
      final dto = ContactoEmergenciaDto.fromJson({'id': 1});

      expect(dto.nombre, '');
      expect(dto.orden, 0);
      expect(dto.esWhatsapp, isFalse);
    });
  });

  group('telefonoInternacional', () {
    test('añade el prefijo 51 a un número local de 9 dígitos', () {
      const c = ContactoEmergencia(
        id: 1,
        nombre: 'X',
        telefono: '974041728',
        esWhatsapp: false,
      );
      expect(c.telefonoInternacional, '+51974041728');
    });

    test('respeta un número que ya trae el prefijo 51', () {
      const c = ContactoEmergencia(
        id: 1,
        nombre: 'X',
        telefono: '51967404172',
        esWhatsapp: false,
      );
      expect(c.telefonoInternacional, '51967404172');
    });

    test('respeta un número internacional que ya trae +', () {
      const c = ContactoEmergencia(
        id: 1,
        nombre: 'X',
        telefono: '+15551234567',
        esWhatsapp: false,
      );
      expect(c.telefonoInternacional, '+15551234567');
    });
  });
}