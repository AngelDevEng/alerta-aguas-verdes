# Paso 4b — Matriz de paridad legacy Kotlin → Flutter

> 2026-10-06. Base: auditoría de `SerenazgoRepository.kt` y de las 9 Activities del
> legacy (evidencia `ruta:línea`), contrastada con el código actual de `mobile/` y
> con los endpoints reales de `backend/src/**`. Leyenda: **Hecho** / **Parcial** /
> **Falta**. Las capturas lado a lado quedan **pendientes** (requieren
> dispositivo/emulador con el legacy compilado): se llenan en esta misma tabla en
> la columna "Captura".

## 1. Pantallas

| # | Pantalla legacy (Activity) | Funciones legacy | Equivalente Flutter | Estado | Evidencia |
|---|---|---|---|---|---|
| 1 | `InicioActivity` (login) | 3 accesos: Admin (usuario+password), Serenazgo (placa+DNI vía `login_patrullero.php`), Ciudadano (sin credenciales) | `login_page.dart` con selector DNI / Placa → `POST /auth/login` y `POST /auth/login/patrullero` | **Parcial** (ciudadano sin credenciales pendiente: el backend nuevo no expide token anónimo y `POST /incidencias` exige token) | `InicioActivity.kt:74-272`; `login_page.dart:74-103` |
| 2 | `MainActivity` (panel ADMIN) | CRUD de unidades/serenazgos: alta, edición, baja, buscar por placa, asociaciones, foto, botón "Ver Monitoreo" | — (feature `unidades` sin `presentation/`) | **Falta** | `MainActivity.kt:138-144`; `mobile/lib/features/unidades/` solo data+domain |
| 3 | `MenuActivity` (menú por rol) | SOS "Ubicación", Emergencia, Reportar Incidente, Mapa de Calor, Ingresar placa, Iniciar/Detener rastreo, Ver mapa | `home_page.dart` 1:1 con `activity_menu.xml` (mismo fondo `@mipmap/menu`, toolbar `#80000000`, botones gráficos en las mismas posiciones y visibilidad por rol: sereno = panel patrulla + rastreo; resto = SOS + Emergencia). SOS conectado (4d.2): GPS + `POST /alertas`, aviso "Auxilio enviado a central" | **Parcial** (visual 1:1; tras el SOS el legacy abre `RastreoActivity` -pendiente 4d.4-; placa, rastreo y mapa de calor pendientes; accesos extra de Flutter -Incidencias/Perfil- eliminados por decisión de 1:1 estricto) | `MenuActivity.kt:71-154`; `activity_menu.xml`; `home_page.dart`; `sos_bloc.dart` |
| 4 | `ReportarIncidenteActivity` | Formulario: tipo, urgencia, descripción, dirección, GPS, enviar | `reportar_incidencia_page.dart` (tipo desde catálogo, prioridad, GPS obligatorio, fotos con reintento, geocoding) | **Hecho** (supera al legacy) | `ReportarIncidenteActivity.kt:87-196`; `reportar_incidencia_page.dart:57-162` |
| 5 | `BuscarPlacaActivity` | Consulta por placa: nombre, DNI, licencia, foto (bug: campos cruzados `:117`) | — | **Falta** (backend `GET /unidades?placa=` listo) | `BuscarPlacaActivity.kt:80-134`; `unidades.controller.ts` findAll |
| 6 | `MapaCalorActivity` | Heatmap osmdroid con filtros de tipo y fechas | — | **Falta** (backend `GET /incidencias/zonas-calor` listo, 4a) | `MapaCalorActivity.kt:80-130`; `incidencias.controller.ts` zonasCalor |
| 7 | `MonitoreoActivity` (ADMIN) | Mapa de flota con polling cada 8 s y contador de patrullas | — | **Falta** (backend `GET /unidades` + `ultima_ubicacion` listos) | `MonitoreoActivity.kt:82-132` |
| 8 | `RastreoActivity` + `LocationTrackingService` | Seguimiento de patrulla (polling 7 s), marcador de alerta activa (5 s), botón "Emergencia atendida", servicio foreground de envío de ubicación | — | **Falta** (backend: `POST /unidades/:id/ubicaciones`, `GET /unidades/:id/rastro`, `GET /alertas/activas`, `PATCH /alertas/:id/estado` listos) | `RastreoActivity.kt:54-146`; `LocationTrackingService.kt:171-213` |
| 9 | `EmergenciaActivity` | 7 botones de llamada/WhatsApp hardcodeados | `emergencias_page.dart` (contactos desde API con `tel:`/`wa.me`) | **Hecho** (supera al legacy) | `EmergenciaActivity.kt:31-97`; `emergencias_page.dart:21-78` |
| — | (sin equivalente legacy) | — | `incidencias_page.dart` + `incidencia_detalle_page.dart` (listado con filtros, detalle, despacho, estados) | **Hecho** (nuevo; el legacy ni usaba su propio listado) | `incidencias_page.dart:52-215`; `incidencia_detalle_page.dart:137-217` |

## 2. Métodos de `SerenazgoRepository.kt` → API nueva

La auditoría previa (`docs/auditoria-inicial.md:52-53`: 1 equivalente, 5 adaptables, 9 rotos) era **pre-4a**. Tras los commits del 4-oct el estado de backend es:

| # | Método legacy | Endpoint nuevo | Backend | Flutter lo consume |
|---|---|---|---|---|
| 1 | `subirImagen` (foto de unidad) | `POST /evidencias` (solo incidencias) — `unidades` no tiene campo imagen (`01_schema.sql`) | Sin equivalente directo | No |
| 2 | `obtenerTodos` | `GET /unidades` | ✅ | No |
| 3 | `obtenerAsociaciones` | `GET /catalogos/asociaciones` | ✅ | No (usecase sin UI) |
| 4 | `buscarPorPlaca` | `GET /unidades?placa=` | ✅ (4a) | No |
| 5 | `insertar` | `POST /unidades` | ✅ | No |
| 6 | `editar` | `PATCH /unidades/:id` | ✅ (4a) | No |
| 7 | `eliminar` (baja física) | `DELETE /unidades/:id` (baja lógica `eliminado_en`) | ✅ (4a, 06_*.sql) | No |
| 8 | `rastrearPatrullero` (Flow 7 s) | `GET /unidades/:id/rastro` | ✅ | No |
| 9 | `obtenerUbicacionPatrullero` | `GET /unidades/:id` (`ultima_ubicacion`) o `rastro?limit=1` | ✅ | No |
| 10 | `actualizarUbicacionPatrullero` (código muerto en legacy) | `POST /unidades/:id/ubicaciones` | ✅ | No |
| 11 | `crearAlertaConToken` (SOS) | `POST /alertas` | ✅ | ✅ `sos_bloc.dart` (4d.2) |
| 12 | `obtenerUltimaAlerta` | `GET /alertas/activas` | ✅ | No |
| 13 | `atenderAlerta` | `PATCH /alertas/:id/estado` | ✅ | No |
| 14 | `crearIncidente` | `POST /incidencias` | ✅ | ✅ `reportar_bloc.dart` |
| 15 | `obtenerIncidentes` (muerto en legacy) | `GET /incidencias` (filtros+paginación) | ✅ | ✅ `incidencias_bloc.dart` |
| 16 | `obtenerZonasCalor` (rompe con `{data:[...]}`) | `GET /incidencias/zonas-calor` (arreglo plano, contrato MAPABASE) | ✅ (4a) | No |

## 3. Resumen

| Capacidad | Backend | Flutter |
|---|---|---|
| Pantallas paridad total | — | 2 Hechas / 2 Parciales / 5 Faltas |
| Métodos con endpoint nuevo | 15 de 16 (falta equivalente de `subirImagen`) | 3 consumidos de 16 |
| SOS (`POST /alertas`) | ✅ | ✅ `features/alertas` (4d.2) |
| Mapa (OSM) | ✅ (`geojson`, `rastro`, `cercanas`) | ❌ placeholder `app_router.dart:193` |
| Rastreo 2.º plano | ✅ (ubicaciones) | ❌ sin plugin de background (solo `ACCESS_FINE_LOCATION`) |
| Login por placa (4a) | ✅ `POST /auth/login/patrullero` | ✅ selector DNI/Placa en `login_page.dart` (4b.1) |

**Conclusión:** el backend quedó en paridad tras el 4a; el hueco de paridad es la
UI Flutter. Orden sugerido (plan 4d): SOS → mapa → rastreo → WebSocket → mapa de
calor → búsqueda/gestión de unidades.

## 4. Pendientes de esta matriz

- [ ] Capturas lado a lado (legacy compilado vs Flutter) por pantalla.
- [ ] Revisar `MonitoreoActivity`: el legacy filtra patrullas con lat/lng ≠ 0; confirmar que `GET /unidades` devuelve `ultima_ubicacion` con ese formato.
- [ ] Definir qué hacer con `subirImagen` (campo `imagen` en `unidades` o descartar).
