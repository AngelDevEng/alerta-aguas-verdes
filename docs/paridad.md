# Paso 4b — Matriz de paridad legacy **Java** → Flutter

> **2026-10-07 — Cambio de referencia.** La primera versión de esta matriz (6-oct) se escribió
> contra el legacy **Kotlin** (`com.example.appadmin`: `InicioActivity.kt`,
> `SerenazgoRepository.kt`…), que ya no es la especificación. El responsable decide que la
> referencia 1:1 canónica es la app **Java** de este repo:
> `AppSerenazgoseguro-android-app-legacy/app/src/main` (`com.example.serenazgoseguro`), cuya
> auditoría funcional completa (32 clases, 14 activities, 3 servicios, 16 layouts) se hizo el
> 2026-10-07. Toda evidencia `ruta:línea` de este documento es relativa a esa carpeta; las
> rutas Java se citan como `Archivo.java:línea`. La copia anidada
> `AppSerenazgoseguro-android-app/` es idéntica (hash por hash) y queda excluida.
> Leyenda: **Hecho** / **Parcial** / **Falta**. Las capturas lado a lado siguen **pendientes**.

## 1. Pantallas y servicios (17 filas)

| # | Pantalla/servicio legacy | Funciones legacy | Equivalente Flutter/backend | Estado | Evidencia |
|---|---|---|---|---|---|
| 1 | `Activity_Panico_Main` (**LAUNCHER**) | Pantalla de pánico ciudadana: SOS circular → `crear_alerta.php` + arranca `CiudadanoTrackingService` + abre `Activity_Rastreo`; grid de 4 cards (POLICIA PNP, SERENAZGO, INCIDENTES, EMERGENCIAS MÚLTIPLES) con llamada directa; buscador de placa en el footer; registro FCM de ciudadano; permisos + optimización de batería; sync SQLite; auto-salto a Rastreo si `en_alerta` | `home_page.dart` **reconstruido 1:1** con `activity_panico_main.xml` (2026-10-07): gradiente `#ADC8E8→#FFFFFF`, header escudo/ALERTA/logomuni, SOS conectado (`POST /alertas`, 4d.2), grilla 2×2 con llamada `tel:` directa (POLICIA PNP / SERENAZGO usando `GET /catalogos/emergencias`), INCIDENTES → `reportar_incidencia_page`, EMERGENCIAS MÚLTIPLES → `emergencias_page`, footer Buscar placa (aviso, fila 6); escudo = stand-in de `admin()` (hoja de sesión) | **Parcial** (falta: tras el SOS abrir rastreo + servicio ciudadano en 2.º plano 4d.4, FCM, auto-salto `en_alerta`; el escudo no lleva a Dashboard/MainActivity, inexistentes) | `activity_panico_main.xml`; `home_page.dart` (claves `menu_sos`, `menu_comisaria`, `menu_serenazgo`, `menu_incidencias`, `menu_otras_emergencias`, `placa_input`, `menu_buscar`, `home_escudo`) |
| 2 | `Activity_Login` | Spinner de rol Administrador/Patrullero; admin por `usuario`+`password` (URL fija `muniaguasverdes…/login.php`), patrullero por placa+password; sesión persistente en prefs; reenvío de token FCM tras login | `login_page.dart` selector DNI/Placa → `POST /auth/login` y `POST /auth/login/patrullero` (4a/4b.1) | **Parcial** (funciona 1:1 en credenciales y persistencia de sesión; falta el registro de token FCM; el admin legacy entra por "usuario" y el nuevo por DNI — adaptable) | `Activity_Login.java:33-36, 101-218`; `login_page.dart:74-103` |
| 3 | `Activity_Patrullero_Dashboard` | Polling 10 s: `obtener_alertas_activas` + `obtener_ubicacion_patrullero`; lista con badges ACTIVA/EN CURSO/ATENDIENDO, distancia Haversine y tiempo; `asignar_alerta` y arranque de `LocationTrackingService`; guard si no hay sesión | Backend listo (`GET /alertas/activas`, `PATCH /alertas/:id/estado`, `GET /unidades/:id/rastro`); Flutter: **sin pantalla** (la barra sereno del home solo tiene rastreo "en preparación") | **Falta** | `Activity_Patrullero_Dashboard.java:58-224`; `alertas.controller.ts:28-42` |
| 4 | `Activity_Rastreo` | Mapa osmdroid CARTO Voyager; patrullero: ubicación del ciudadano cada 5 s + suya cada 7 s; ciudadano: su posición + alerta activa cada 5 s; marcadores animados con rotación, ruta polilínea, ETA; botones Finalizar/Cancelar alerta | Backend listo (`GET /alertas/:id`, `GET /unidades/:id/rastro`); Flutter: `app_router.dart:193` **placeholder** "Mapa operativo" | **Falta** | `Activity_Rastreo.java:101-446`; `app_router.dart:193-202` |
| 5 | `Activity_Mapa_Calor` | Heatmap con filtros de tipo y fechas (`obtener_zonas_calor`), colores por `nivel_urgencia`, leyenda, contador | Backend listo (`GET /incidencias/zonas-calor`, contrato MAPABASE); Flutter: botón "Mapa de Calor" del home → "en preparación" (`home_page.dart:359`) | **Falta** | `Activity_Mapa_Calor.java:89-225`; `incidencias.controller.ts:34` |
| 6 | `Activity_Buscar_Placa` | Búsqueda **pública** por placa → nombre, DNI, asociación, licencia, foto (Glide); input filtrado `A-ZÑ0-9-`; auto-búsqueda desde el launcher | Backend listo (`GET /unidades?placa=`); Flutter: botón "Ingresar placa" → "en preparación" | **Falta** (además: el endpoint nuevo exige token; el legacy es público) | `Activity_Buscar_Placa.java:73-209`; `unidades.controller.ts:30` |
| 7 | `Activity_Reportar_Incidencia` | Tipo (5 opciones), urgencia (Bajo/Medio/Alto), descripción, GPS obligatorio, dirección, envío | `reportar_incidencia_page.dart` → `POST /incidencias` (tipo desde catálogo, fotos con reintento, geocoding) | **Hecho** (supera al legacy) | `Activity_Reportar_Incidencia.java:68-194`; `reportar_incidencia_page.dart:57-162` |
| 8 | `Activity_Emergencias_Grid` | Grid 3×2: Bomberos/Mujer/Serenazgo/Comisaria (teléfono directo), WhatsApp Serenazgo, **atajo a Mapa de Calor**; números desde prefs "CENTRAL" (offline) | `emergencias_page.dart` → `GET /catalogos/emergencias` (+ `/whatsapp`) con `tel:`/`wa.me`; **atajo "Mapa de Calor"** añadido al final de la lista (aviso: fila 5 pendiente) | **Parcial** (solo queda el catálogo sin red/offline; el atajo ya está) | `Activity_Emergencias_Grid.java:27-67`; `emergencias_page.dart:44-108` |
| 9 | `MainActivity` (menú admin) | Dos cards: "REGISTRO DE CONDUCTOR" y "CONTACTOS DE EMERGENCIA"; cerrar sesión; guard `rol != admin` | — (sin pantalla admin en Flutter) | **Falta** | `MainActivity.java:25-71` |
| 10 | `Activity_Central_List` | Lista admin de contactos de central (RecyclerView), sync remota `obtener_numeros`, refresh | Backend: solo lectura (`GET /catalogos/emergencias`); **sin CRUD**; Flutter: nada | **Falta** | `Activity_Central_List.java:34-85`; `catalogos.controller.ts:20` |
| 11 | `Activity_Central_Form` | Edición de contacto (nombre/teléfono): SQLite local + `editar_central.php`; degrada a guardado local sin red | Backend **sin** `POST/PATCH` de contactos; Flutter: nada | **Falta (backend + Flutter)** | `Activity_Central_Form.java:32-85` |
| 12 | `Activity_Conductores_List` | Lista admin de conductores con búsqueda en vivo (`TextWatcher`), refresh (`todos_serenazgo`), alta | Backend listo (`GET /unidades`); Flutter: feature `unidades` sin `presentation/` | **Falta** | `Activity_Conductores_List.java:44-176`; `unidades.controller.ts:30` |
| 13 | `Activity_Conductores` | Alta/edición/baja de conductor: placa, nombre, DNI, asociación, licencia, **foto (galería/cámara → Base64)** | Backend CRUD listo (`POST/PATCH/DELETE /unidades`) **pero `unidades` no tiene campo imagen** (`01_schema.sql`); Flutter: nada | **Falta** (backend CRUD listo; foto pendiente de decisión) | `Activity_Conductores.java:68-411`; `unidades.controller.ts:25-57` |
| 14 | `services.LocationTrackingService` | Foreground "🚐 Patrullando": GPS 5 s, envío ≥10 m o cada 120 s → `actualizar_ubicacion_patrullero`; notificación persistente; tap → dashboard | Backend listo (`POST /unidades/:id/ubicaciones`); Flutter **sin plugin de background** (solo `ACCESS_FINE_LOCATION`) | **Falta** | `LocationTrackingService.java:58-191`; `unidades.controller.ts:40` |
| 15 | `services.CiudadanoTrackingService` | Foreground "🔴 Alerta SOS activa": misma cadencia → `actualizar_ubicacion_ciudadano` (`id_alerta`, lat, lng); tap → `Activity_Rastreo` | Backend **sin equivalente** (no hay endpoint de ubicación del ciudadano en alerta); Flutter: nada | **Falta (backend + Flutter)** | `CiudadanoTrackingService.java:54-179` |
| 16 | `services.FCMService` | Push: 7 tipos de mensaje con destinos distintos (`nueva_alerta`, `alerta_aceptada`, `alerta_atendida`, `alerta_cancelada[_por_ciudadano]`, `alerta_reenviada`, `nuevo_incidente`); token en prefs | Backend sin FCM; Flutter sin push. **Regla vigente** (`plan.md`): "No añadir push (FCM) sin consultar" → **requiere decisión** | **Falta (decidir)** | `FCMService.java:22-164` |
| 17 | `Mdav` (SQLite) + SharedPreferences | Offline: tablas `SERENAZGO` y `CENTRAL` sincronizadas con MySQL; sesión y teléfonos en prefs; auto-login | Flutter: sesión persistente (tokens) ✅ y fotos de incidencia con reintento ✅; sin sync offline de conductores ni contactos | **Parcial** | `Mdav.java:31-221` |

**Resumen pantallas: 1 Hecho / 4 Parcial / 12 Falta.**

## 2. Endpoints PHP (`Config.java` + hardcodeados) → API nueva

| # | Método legacy | Evidencia | Endpoint nuevo | Backend | Flutter lo consume |
|---|---|---|---|---|---|
| 1 | `crear_alerta.php` (SOS ciudadano) | `Config.java:8` | `POST /alertas` (público, abre incidencia CRITICA) | ✅ | ✅ `sos_bloc.dart` (4d.2) |
| 2 | `cancelar_alerta.php` | `Config.java:9` | `PATCH /alertas/:id/estado` (`CANCELADA`) | ✅ | No |
| 3 | `asignar_alerta.php` (`atendido_por`) | `Config.java:10` | `PATCH /alertas/:id/estado` (`ATENDIDA` fija `atendido_por`) + `PATCH /incidencias/:id/asignar` | ✅ (contrato de estados distinto: `ACTIVA/ATENDIDA/CANCELADA/FALSA` vs badges legacy ACTIVA/EN CURSO/ATENDIENDO) | No |
| 4 | `atender_alerta.php` | `Config.java:11` | `PATCH /alertas/:id/estado` (`ATENDIDA`; cierra incidencia y libera unidad) | ✅ | No |
| 5 | `obtener_ultima_alerta.php` | `Config.java:12` | `GET /alertas/activas` o `GET /alertas/:id` | ✅ | No |
| 6 | `obtener_alertas_activas.php` | `Config.java:13` | `GET /alertas/activas` | ✅ | No |
| 7 | `obtener_ubicacion_patrullero.php` | `Config.java:14` | `GET /unidades/:id` (`ultima_ubicacion`) o `rastro?limit=1` | ✅ | No |
| 8 | `actualizar_ubicacion_patrullero.php` | `Config.java:15` | `POST /unidades/:id/ubicaciones` | ✅ | No |
| 9 | `actualizar_ubicacion_ciudadano.php` | `Config.java:16` | **sin equivalente** | ❌ | No |
| 10 | `obtener_zonas_calor.php` | `Config.java:17` | `GET /incidencias/zonas-calor` (contrato MAPABASE) | ✅ | No |
| 11 | `crear_incidente.php` | `Config.java:18` | `POST /incidencias` | ✅ (exige token: el legacy no lo hacía) | ✅ `reportar_bloc.dart` |
| 12 | `registrar_dispositivo.php` (FCM) | `Config.java:19` | **sin equivalente** (FCM fuera de alcance por ahora) | ❌ | No |
| 13 | `login_patrullero.php` (placa+password) | `Config.java:20` | `POST /auth/login/patrullero` | ✅ | ✅ `login_page.dart` (4b.1) |
| 14 | `login.php` (admin usuario+password) | `Activity_Login.java:34` | `POST /auth/login` (DNI+password) | ✅ | ✅ `login_page.dart` |
| 15 | `obtener_numeros.php` (central) | `Config.java:21` | `GET /catalogos/emergencias` | ✅ | ✅ `emergencias_page.dart` |
| 16 | `editar_central.php` | `Config.java:22` | **sin equivalente** (la tabla `contactos_emergencia` existe; no hay CRUD) | ❌ | No |
| 17 | `buscar_serenazgo.php?placa=` | `Activity_Buscar_Placa.java:150` | `GET /unidades?placa=` | ✅ (exige auth; legacy público) | No |
| 18 | `todos_serenazgo.php?t=` | `Activity_Conductores_List.java:112-114` | `GET /unidades` | ✅ | No |
| 19 | `insertar_serenazgo.php` (imagen Base64) | `Activity_Conductores.java:159` | `POST /unidades` | ✅ (**sin campo imagen**) | No |
| 20 | `editar_serenazgo.php` | `Activity_Conductores.java:157` | `PATCH /unidades/:id` | ✅ (sin imagen) | No |
| 21 | `eliminar_serenazgo.php` (baja física) | `Activity_Conductores.java:180` | `DELETE /unidades/:id` (baja lógica `eliminado_en`) | ✅ | No |
| 22 | `obtener_serenazgo.php` (sync SQLite) | `Mdav.java:106` | `GET /unidades` | ✅ | No |

## 3. Resumen

| Capacidad | Backend | Flutter |
|---|---|---|
| Pantallas paridad | — | 1 Hecha / 4 Parciales / 12 Faltas |
| Endpoints PHP con equivalente nuevo | **19 de 22** (faltan: ubicación del ciudadano, registrar_dispositivo/FCM, editar_central) | **5 de 22** consumidos |
| SOS ciudadano (`POST /alertas`) | ✅ público | ✅ `features/alertas` (4d.2) |
| Mapa (rastreo, calor, flota) | ✅ (`geojson`, `rastro`, `zonas-calor`, `cercanas`) | ❌ placeholder `app_router.dart:193` |
| Rastreo en 2.º plano (2 servicios legacy) | ✅ parcial (patrullero sí; ciudadano ❌) | ❌ sin plugin de background |
| Push FCM (7 tipos) | ❌ | ❌ (fuera de alcance: requiere decisión) |
| Admin (conductores + contactos de central) | ✅ unidades / ❌ contactos CRUD | ❌ sin `presentation/` de `unidades` |

## 4. Diferencias transversales (requieren decisión)

1. **Ciudadano sin cuenta.** El legacy funciona **entero sin login** (launcher, SOS, reporte,
   búsqueda de placa, emergencias). La app nueva exige sesión para todo (`app_router.dart:161-171`)
   y el backend exige token en `POST /incidencias` y `GET /unidades`. El SOS ya es público; falta
   decidir el resto (cuenta ciudadana sembrada vs token anónimo con rate limit).
2. **El home se reconstruyó 1:1 contra `activity_panico_main.xml` (2026-10-07).** Se quitó el
   menú del legacy *Kotlin* (panel patrulla, barra de rastreo, botones Reportar/Mapa de Calor
   inferiores): el launcher Java no los tiene. Divergencia restante: en el legacy, el patrullero
   y el admin aterrizan en Dashboard/MainActivity al entrar; acá todos aterrizan en el launcher
   hasta construir las filas 3 y 9, y el escudo hace de `admin()` (hoja de sesión). La animación
   `pulse` del logomuni no se replica (una animación infinita rompería `pumpAndSettle` de los
   tests sin aportar función).
3. **Diseño:** la paleta del legacy Java (gradiente `#ADC8E8→#FFFFFF`, verde `#087A3B`, azul
   `#0A6C9C`, rojo `#D32F2F`, footer `#3D8FA8`, barra de 4 colores) difiere de la que copió
   `app_theme.dart` (hex del `colors.xml` del legacy Kotlin, `verde #FF4CAF50`). Re-auditar
   `app_theme.dart` contra los layouts Java (`res/layout/*.xml`, `res/drawable/*.xml`).
4. **FCM:** el legacy depende de push para 7 flujos (asignación de alertas en tiempo real, entre
   ellos). Sin push, el dashboard patrullero tendría que usar polling/WebSocket (paso 5 del plan).
5. **El legacy Java se mantiene solo como referencia local (decisión del usuario, 2026-10-07).**
   La modernización no lo versiona: `.gitignore` ignora `AppSerenazgoseguro-android-app-legacy/`
   al completo, lo que incluye su `servidor/` PHP con credenciales y `google-services.json*`
   (con el `.bak`). Regla de `plan.md`: hosting/php **no entran a ningún repo**.
6. **Alertas: contratos de estado distintos.** Legacy separa *asignar* (`atendido_por`) de
   *atender*; el nuevo colapsa en `estado` (`ACTIVA/ATENDIDA/CANCELADA/FALSA`) + `atendido_por`.
   Mapear los badges del dashboard a este contrato al implementarlo.

## 5. Pendientes de esta matriz

- [ ] Capturas lado a lado (legacy Java compilado vs Flutter) por pantalla.
- [ ] Decidir: ciudadano sin cuenta (4.1) y FCM (4.4).
- [ ] Construir Dashboard patrullero (fila 3) y MainActivity admin (fila 9): son el destino del
      `admin()` del escudo y estarán tras rastreo/mapa según el orden 4d.
- [ ] Decidir qué hacer con la **foto de conductor** (`subirImagen`): campo `imagen` en
      `unidades` o descartar.
- [ ] Confirmar que `GET /unidades` devuelve `ultima_ubicacion` con el formato que espera el
      dashboard (lat/lng ≠ 0, como filtraba el legacy).
- [ ] Considerar `git update-index --skip-worktree` o `.gitignore` para
      `AppSerenazgoseguro-android-app-legacy/servidor/`.
