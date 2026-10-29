/// Eventos del mapa operativo.
sealed class MapaEvent {
  const MapaEvent();
}

/// Carga inicial, recarga manual o reintento tras un error.
///
/// Un solo evento para los tres casos: los tres hacen exactamente lo mismo
/// (pedir el geojson y la posicion) y distinguirlos obligaria a que el BLoC
/// guarde de donde vino la ultima carga.
class CargarMapa extends MapaEvent {
  const CargarMapa();
}

/// El usuario toco "centrar en mi": solo pide la posicion, sin recargar la
/// capa de incidencias.
class CentrarEnMi extends MapaEvent {
  const CentrarEnMi();
}
