/// Lectura defensiva de JSON en la capa `data/`.
///
/// Existian copias de estos helpers dentro de cada DTO. Con cuatro archivos de
/// modelos la copia ya se dividio: cada una toleraba un caso distinto y ninguna
/// era igual a las otras. Un solo lugar garantiza que `null`, `""` y `"42"`
/// significen lo mismo en toda la app.
///
/// La regla es siempre la misma: ante un valor inesperado, devolver el valor por
/// defecto en vez de lanzar. Un campo raro del backend no puede dejar la
/// pantalla en blanco.
library;

/// Numero como double. Acepta int, double y el string que devuelve Postgres
/// cuando la columna es `numeric`.
double aDoble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// Numero nullable, para coordenadas que pueden no venir.
double? aDobleOpcional(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    if (v.trim().isEmpty) return null;
    return double.tryParse(v);
  }
  return null;
}

int aEntero(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Timestamp ISO-8601 a [DateTime], o null.
///
/// Devuelve el valor **sin** convertir de zona: Postgres devuelve `2026-03-01
/// 12:00:00-03` y `DateTime.parse` ya lo interpreta como UTC. Convertirlo de
/// nuevo correria la hora dos veces.
DateTime? aFecha(dynamic v) {
  if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v.trim());
  return null;
}

/// Texto obligatorio: nunca null, cadena vacia si el campo falta.
String aTexto(dynamic v) => v?.toString() ?? '';

/// Texto opcional, donde `""` se normaliza a null.
///
/// El backend persiste cadenas vacias en varias columnas (`descripcion`,
/// `referencia`, `placa`). Sin esta normalizacion la UI tendria que distinguir
/// "vacio" de "no informado" en cada widget.
String? aTextoOpcional(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

bool aBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return false;
}

/// Lee una lista de objetos, descartando los elementos que no sean mapas.
///
/// Un solo elemento raro en la respuesta no puede hacer fallar toda la pagina.
List<Map<String, dynamic>> aListaDeMapas(dynamic data) {
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}