/// Descarte de respuestas obsoletas en BLoCs con peticiones concurrentes.
///
/// El problema que resuelve: al disparar dos consultas seguidas (cambiar dos
/// filtros muy rapido, pull-to-refresh sobre una carga), las respuestas pueden
/// volver en cualquier orden. La mas lenta suele ser la de la consulta vieja, y
/// si emite sin control termina pisando la pantalla con datos que ya no
/// corresponden a lo que el usuario ve seleccionado.
///
/// El contador vive aca y no en cada BLoC porque son tres los que lo necesitan
/// y la explicacion de por que es necesario es de las mas largas del modulo.
///
/// Uso tipico:
///
/// ```dart
/// final token = _guarda.nuevoToken();
/// final r = await _listar();
/// if (_guarda.estaVencido(token)) return;   // incluye el bloc ya cerrado
/// ```
class GuardaRespuestas {
  int _ultimo = 0;

  /// Registra una consulta nueva y devuelve su token.
  int nuevoToken() => ++_ultimo;

  /// Si [token] ya no es la consulta vigente: su respuesta hay que descartarla.
  ///
  /// Incorpora el caso `isClosed` porque siempre se consulta junto a el y
  /// separarlos obliga a repetir la comprobacion en cada `if`, que es
  /// exactamente donde uno se olvida.
  bool estaVencido(int token, {required bool isClosed}) =>
      isClosed || token != _ultimo;

  /// Invalida toda consulta en vuelo sin lanzar una nueva.
  ///
  /// Lo usa `close()`: sin esto, un BLoC destruido mientras espera una respuesta
  /// puede emitir un estado que Flutter ya no tiene a quien mostrarle.
  void invalidarTodo() => _ultimo++;
}