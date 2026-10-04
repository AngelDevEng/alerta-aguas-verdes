import 'package:alerta_aguas_verdes/core/parsing/lector_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// El criterio de estos helpers es "ante un valor inesperado, devolver el
/// default y seguir". Los tests fijan los bordes donde esa decision cambia un
/// resultado visible en pantalla: un timestamp corrido dos veces, un `""` que
/// se muestra como "(ninguno)" o una coordenada que queda en 0 y manda a un
/// punto en el golfo.
void main() {
  group('aDoble', () {
    test('acepta int, double y el string de una columna numeric', () {
      expect(aDoble(3), 3.0);
      expect(aDoble(3.5), 3.5);
      // Postgres devuelve los `numeric` como string; es el caso real, no teorico.
      expect(aDoble('-12.0431'), -12.0431);
    });

    test('un valor ilegible cae en 0 en vez de romper', () {
      expect(aDoble(null), 0);
      expect(aDoble('n/d'), 0);
      expect(aDoble(<int>[1]), 0);
    });

    test('un numero con separador de miles no se toma como valido', () {
      // `double.tryParse('1,5')` devuelve null en Dart: mejor 0 y una fila
      // visible que una coordenada corrida que manda la incidencia a otra parte.
      expect(aDoble('1,5'), 0);
    });
  });

  group('aDobleOpcional', () {
    test('distingue "no informado" de "cero"', () {
      // Un 0 en latitud es el golfo de Guayaquil; un null es "el backend no lo
      // mando". Confundirlos pone marcadores en el mapa.
      expect(aDobleOpcional(null), isNull);
      expect(aDobleOpcional(''), isNull);
      expect(aDobleOpcional('   '), isNull);
      expect(aDobleOpcional(0), 0);
      expect(aDobleOpcional('0'), 0);
    });

    test('un string no numerico es null y no 0', () {
      expect(aDobleOpcional('n/d'), isNull);
    });
  });

  group('aEntero', () {
    test('trunca los decimales en vez de redondear', () {
      expect(aEntero(3.9), 3);
    });

    test('acepta el string de un id numerico', () {
      expect(aEntero('7'), 7);
    });

    test('un valor ilegible cae en 0', () {
      expect(aEntero('tipo-3'), 0);
      expect(aEntero(null), 0);
    });
  });

  group('aFecha', () {
    test('interpreta el desplazamiento de Postgres sin volver a convertir', () {
      // Postgres serializa con offset: `DateTime.parse` ya lo lleva a UTC.
      // Convertirlo de nuevo correria la hora dos veces y el historial de la
      // incidencia mostraria movimientos a destiempo.
      final f = aFecha('2026-03-01T12:00:00-03:00')!;

      expect(f.isUtc, isTrue);
      expect(f.hour, 15);
    });

    test('acepta el timestamp sin zona del backend', () {
      expect(aFecha('2026-03-01T12:00:00.000Z'), DateTime.utc(2026, 3, 1, 12));
    });

    test('devuelve null en vez de lanzar con algo que no es fecha', () {
      expect(aFecha(null), isNull);
      expect(aFecha(''), isNull);
      expect(aFecha('  '), isNull);
      expect(aFecha('ayer'), isNull);
      expect(aFecha(1740000000), isNull, reason: 'un epoch no es un ISO-8601');
    });
  });

  group('texto', () {
    test('aTexto nunca devuelve null', () {
      expect(aTexto(null), '');
      expect(aTexto('hola'), 'hola');
      expect(aTexto(12), '12');
    });

    test('aTextoOpcional normaliza la cadena vacia a null', () {
      // El backend persiste "" en `descripcion`, `referencia` y `placa`. Sin
      // normalizar, cada widget tendria que decidir si "(vacio)" o "no
      // informado".
      expect(aTextoOpcional(null), isNull);
      expect(aTextoOpcional(''), isNull);
      expect(aTextoOpcional('dato'), 'dato');
    });

    test('aTextoOpcional no toca un string de espacios', () {
      // A diferencia de la fecha, aqui no se hace `trim`: " " es un valor
      // presente y borrarlo seria mentir sobre lo que hay en la base.
      expect(aTextoOpcional(' '), ' ');
    });
  });

  group('aBool', () {
    test('acepta las tres formas que manda la base', () {
      expect(aBool(true), isTrue);
      expect(aBool(1), isTrue);
      expect(aBool(0), isFalse);
      expect(aBool('true'), isTrue);
      expect(aBool('TRUE'), isTrue);
      expect(aBool('false'), isFalse);
      expect(aBool('1'), isFalse);
    });

    test('un null es false y no una excepcion', () {
      expect(aBool(null), isFalse);
      expect(aBool(<String>[]), isFalse);
    });
  });

  group('aListaDeMapas', () {
    test('descarta los elementos que no son mapas sin perder el resto', () {
      // Un elemento raro no puede hacer fallar toda la pagina de historial.
      final r = aListaDeMapas([
        {'a': 1},
        'basura',
        null,
        {'b': 2},
      ]);

      expect(r.length, 2);
      expect(r.first['a'], 1);
      expect(r.last['b'], 2);
    });

    test('devuelve una lista vacia si la respuesta no es una lista', () {
      expect(aListaDeMapas(null), isEmpty);
      expect(aListaDeMapas({}), isEmpty);
      expect(aListaDeMapas('[]'), isEmpty);
    });

    test('no se puede crecer desde afuera', () {
      final r = aListaDeMapas([
        {'a': 1}
      ]);

      expect(() => r.add({'b': 2}), throwsUnsupportedError);
    });
  });
}
