/// Topes del reporte de una incidencia, compartidos por la pagina y los widgets.
///
/// Viven aparte para que la pagina y `SelectorFotos` no se importen entre si.
library;

/// Lado maximo de una foto. El backend acepta hasta 15 MB; recortar y
/// recomprimir evita llegar al limite con una foto de 8 MP de un celular.
///
/// Es `double` y no `int` porque es lo que espera `image_picker`.
const double kMaxLadoFoto = 1600;

/// Cuantas fotos se pueden adjuntar a un reporte.
///
/// Es un tope propio: el backend no lo impone, pero subir 20 fotos de 15 MB en
/// una conexion movil es una espera interminable para el usuario y un gasto de
/// datos que el backend paga en Supabase Storage.
const int kMaxFotosReporte = 4;
