# MAPA DE CALOR — Incidentes de Seguridad Ciudadana

## Objetivo

Implementar un sistema de reporte de incidentes con mapa de calor para identificar las zonas más recurrentes donde ocurren hechos delictivos (sicariato, robo, agresión, violencia, etc.) y así poder enviar patrullaje personalizado a esas áreas.

---

## Fase 1 — Base de Datos

### Nueva tabla: `incidentes`

```sql
CREATE TABLE incidentes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tipo VARCHAR(50) NOT NULL,
  descripcion TEXT,
  latitud DECIMAL(10,8) NOT NULL,
  longitud DECIMAL(11,8) NOT NULL,
  direccion VARCHAR(255),
  nivel_urgencia ENUM('bajo','medio','alto') DEFAULT 'medio',
  estado ENUM('pendiente','en_proceso','resuelto') DEFAULT 'pendiente',
  reportado_por INT DEFAULT NULL,
  fecha_incidente DATETIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_ubicacion (latitud, longitud),
  INDEX idx_tipo (tipo),
  INDEX idx_fecha (fecha_incidente)
);
```

**Archivo SQL:** `hosting/database/incidentes.sql`

---

## Fase 2 — PHP APIs

| Archivo | Método | Descripción |
|---|---|---|
| `hosting/apis/crear_incidente.php` | POST | Crear un nuevo incidente |
| `hosting/apis/obtener_incidentes.php` | GET | Listar incidentes con filtros (tipo, fecha, estado) |
| `hosting/apis/obtener_incidente.php` | GET | Obtener detalle de un incidente por ID |
| `hosting/apis/actualizar_incidente.php` | POST | Cambiar estado o nivel de urgencia |
| `hosting/apis/obtener_zonas_calor.php` | GET | Devolver puntos agrupados por zona para el heatmap |

### Endpoint `obtener_zonas_calor.php`

Agrupa incidentes por cuadrícula (~100m) y devuelve:

```json
[
  { "lat": -3.501, "lng": -80.273, "peso": 12, "tipo_mas_comun": "robo" },
  { "lat": -3.505, "lng": -80.280, "peso": 8,  "tipo_mas_comun": "agresion" }
]
```

- `peso`: cantidad de incidentes en esa zona
- `tipo_mas_comun`: el tipo de incidente más frecuente en esa cuadrícula

---

## Fase 3 — Android: Data Model

### `Incidente.kt`

```kotlin
data class Incidente(
    val id: Int,
    val tipo: String,
    val descripcion: String,
    val latitud: Double,
    val longitud: Double,
    val direccion: String,
    val nivelUrgencia: String,
    val estado: String,
    val fechaIncidente: String
)
```

### `ZonaCalor.kt`

```kotlin
data class ZonaCalor(
    val lat: Double,
    val lng: Double,
    val peso: Int,
    val tipoMasComun: String
)
```

### `SerenazgoRepository.kt`

Agregar métodos:
- `createIncidente(...)` — Volley POST a `crear_incidente.php`
- `getIncidentes(filtros, callback)` — Volley GET a `obtener_incidentes.php`
- `getZonasCalor(fechaInicio, fechaFin, callback)` — Volley GET a `obtener_zonas_calor.php`
- `actualizarIncidente(id, estado, nivelUrgencia, callback)` — Volley POST a `actualizar_incidente.php`

### `Constants.kt`

Agregar:
```kotlin
const val API_CREAR_INCIDENTE = "$BASE_URL/apis/crear_incidente.php"
const val API_OBTENER_INCIDENTES = "$BASE_URL/apis/obtener_incidentes.php"
const val API_OBTENER_INCIDENTE = "$BASE_URL/apis/obtener_incidente.php"
const val API_ACTUALIZAR_INCIDENTE = "$BASE_URL/apis/actualizar_incidente.php"
const val API_ZONAS_CALOR = "$BASE_URL/apis/obtener_zonas_calor.php"
```

---

## Fase 4 — Android: MapaCalorActivity

### Nueva Activity

- **Archivo:** `app/src/main/java/com/example/appadmin/MapaCalorActivity.kt`
- **Layout:** `app/src/main/res/layout/activity_mapa_calor.xml`

### Funcionalidad

| Elemento | Descripción |
|---|---|
| `MapView` (osmdroid) | Mapa base con OpenStreetMap |
| Capa de calor | Círculos semitransparentes rojo → naranja → amarillo según densidad |
| Spinner filtro tipo | Filtrar por tipo de incidente (Todos, Sicariato, Robo, Agresión, Violencia, Otro) |
| DatePicker rango | Seleccionar desde/hasta para filtrar por fecha |
| Botón "Actualizar" | Refrescar el heatmap con los filtros aplicados |
| OnClick en zona | Mostrar en un Toast o Popup: tipo más común + cantidad de incidentes |

### Lógica del heatmap

- Se dibujan círculos superpuestos en el `MapView` con `Paint` semitransparente
- Color según `peso`:
  - Bajo (1-3): amarillo (#FFEB3B)
  - Medio (4-8): naranja (#FF9800)
  - Alto (9+): rojo (#F44336)
- Radio del círculo proporcional al peso

---

## Fase 5 — Menú y Navegación

### `MenuActivity.kt`

Agregar botón/opción **"Mapa de Calor"** que abre `MapaCalorActivity`.

### `AndroidManifest.xml`

Registrar la nueva Activity:

```xml
<activity android:name=".MapaCalorActivity" />
```

---

## Fase 6 — Reporte desde App Ciudadana (Futuro)

Los endpoints ya estarán listos para que la app ciudadana consuma:

1. Ciudadano abre app → selecciona "Reportar Incidente"
2. GPS obtiene ubicación automática
3. Selecciona tipo (Sicariato, Robo, Agresión, Violencia, Otro)
4. Agrega descripción opcional
5. Envía → `POST /apis/crear_incidente.php`
6. Incidente queda en estado `pendiente`
7. Admin lo revisa y cambia estado a `en_proceso` o `resuelto`

---

## Archivos a Crear

| # | Archivo |
|---|---|
| 1 | `hosting/database/incidentes.sql` |
| 2 | `hosting/apis/crear_incidente.php` |
| 3 | `hosting/apis/obtener_incidentes.php` |
| 4 | `hosting/apis/obtener_incidente.php` |
| 5 | `hosting/apis/actualizar_incidente.php` |
| 6 | `hosting/apis/obtener_zonas_calor.php` |
| 7 | `app/src/main/java/com/example/appadmin/models/Incidente.kt` |
| 8 | `app/src/main/java/com/example/appadmin/models/ZonaCalor.kt` |
| 9 | `app/src/main/java/com/example/appadmin/MapaCalorActivity.kt` |
| 10 | `app/src/main/res/layout/activity_mapa_calor.xml` |

## Archivos a Modificar

| # | Archivo | Cambio |
|---|---|---|
| 1 | `app/src/main/java/com/example/appadmin/repositories/SerenazgoRepository.kt` | Agregar métodos de incidentes y zonas de calor |
| 2 | `app/src/main/java/com/example/appadmin/utils/Constants.kt` | Agregar URLs de los nuevos endpoints |
| 3 | `app/src/main/java/com/example/appadmin/MenuActivity.kt` | Agregar botón "Mapa de Calor" |
| 4 | `app/src/main/AndroidManifest.xml` | Registrar `MapaCalorActivity` |
