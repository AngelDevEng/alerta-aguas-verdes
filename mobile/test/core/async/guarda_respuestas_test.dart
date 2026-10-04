import 'package:alerta_aguas_verdes/core/async/guarda_respuestas.dart';
import 'package:flutter_test/flutter_test.dart';

/// El guardia es la pieza que descarta respuestas vieja. Si falla, el sintoma no
/// es un crash: es una pantalla que muestra los datos del filtro anterior sin
/// que nadie entienda por que. Por eso tiene test propio y no queda escondido
/// dentro del primer bloc que lo usa.
void main() {
  group('nuevoToken', () {
    test('devuelve valores distintos y crecientes en cada consulta', () {
      final guarda = GuardaRespuestas();

      final a = guarda.nuevoToken();
      final b = guarda.nuevoToken();

      expect(a, isNot(b));
      expect(b, greaterThan(a));
    });

    test('el primer token arranca en 1', () {
      expect(GuardaRespuestas().nuevoToken(), 1);
    });
  });

  group('estaVencido', () {
    test('el token recien emitido no esta vencido', () {
      final guarda = GuardaRespuestas();
      final token = guarda.nuevoToken();

      expect(guarda.estaVencido(token, isClosed: false), isFalse);
    });

    test('el token de una consulta anterior queda vencido', () {
      final guarda = GuardaRespuestas();

      final viejo = guarda.nuevoToken();
      guarda.nuevoToken(); // segunda consulta, la que manda

      expect(guarda.estaVencido(viejo, isClosed: false), isTrue);
    });

    test('todo esta vencido si el bloc se cerro, aunque sea el token nuevo', () {
      // El caso que hace falta el chequeo de `isClosed`: la respuesta llega
      // justo despues de que el usuario salio de la pantalla. Sin esto, el bloc
      // emite a un `StreamController` cerrado y revienta el assertion de Flutter.
      final guarda = GuardaRespuestas();
      final token = guarda.nuevoToken();

      expect(guarda.estaVencido(token, isClosed: true), isTrue);
    });
  });

  group('invalidarTodo', () {
    test('vence la consulta en vuelo sin emitir una nueva', () {
      final guarda = GuardaRespuestas();
      final enVuelo = guarda.nuevoToken();

      guarda.invalidarTodo();

      expect(guarda.estaVencido(enVuelo, isClosed: false), isTrue);
      // El proximo token se emite con normalidad: invalidar no deja el guardia
      // inservible.
      expect(guarda.estaVencido(guarda.nuevoToken(), isClosed: false), isFalse);
    });
  });
}
