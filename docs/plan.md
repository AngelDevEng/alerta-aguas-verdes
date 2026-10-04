# Plan de ejecución — Modernización Aguas Verdes

> Última actualización: 2026-10-04. Decisiones tomadas con el responsable del proyecto.
> Cliente móvil oficial: **Flutter (Android e iOS)**. La app Kotlin legacy NO se modifica:
> es la especificación de referencia (diseño y funciones) y el respaldo, y vive en un
> repo privado aparte. `hosting/` y `php/` del legacy no entran a ningún repo.

## Estructura de repositorios

| Repo | Contenido | Visibilidad |
|---|---|---|
| `alerta-aguas-verdes` | `/backend`, `/database`, `/mobile` (Flutter), `/docs` | remoto: github.com/AngelDevEng/alerta-aguas-verdes |
| `AppSerenazgoseguro-legacy` | Kotlin: `app/`, `gradle/`, archivos gradle, MAPABASE.md | **privado** |
| `aguas-verdes-LEGADO-FUERA-DE-GIT` (carpeta local, NO repo) | `hosting/`, `php/` del legacy | **ningún repo** (PII + credenciales) |

## Pasos

- [x] **0. Git** — repo único con historial del remoto, sin historial paralelo; escaneo
  de secretos/PII antes del primer commit; commit en `main`; una rama por Sprint.
- [ ] **1. Verificación en Render** — URL real del servicio, `GET /api/v1/health`,
  registrar URL en README/CI. Migraciones SQL siguen siendo manuales.
- [ ] **2. Seguridad** — rotar credenciales legacy; rate limiting en login;
  `USER` no-root y shutdown hooks en Dockerfile; quitar DNI de los logs
  (`auth.service.ts`); revisar CORS_ORIGIN en producción.
- [ ] **3. Pruebas y CI** — Jest en backend (hoy 0 tests), `flutter test` +
  `flutter analyze` en CI (GitHub Actions).
- [ ] **4. Contrato y paridad** (ver abajo).
- [ ] **5. WebSocket** — gateway con handshake autenticado + cliente Flutter con
  reconexión y respaldo REST. Confirmar en la documentación vigente de Render los
  límites de WebSocket e inactividad del plan free, citando la fuente.
- [ ] **6. Estadísticas (H6)** — zonas de calor según `docs/MAPABASE.md` (grilla
  ~100 m, `[{lat,lng,peso,tipo_mas_comun}]`, umbrales de color 1-3/4-8/9+).
- [ ] **7. Repositorios** — capa Repository en el backend (hoy SQL en los 6 services).

## Paso 4 — Contrato y paridad (detalle)

a) **Backend, endpoints a agregar:**
   - `POST /auth/login/patrullero` (placa + password). **Decisión de modelo: SIN
     cambios de esquema.** Resolución: `placa → unidades_serenazgo.placa →
     responsable_id → usuarios → bcrypt`. Reglas:
     placa normalizada (trim, mayúsculas, sin guiones ni espacios) antes de buscar;
     mismo mensaje genérico de error para placa inexistente, unidad sin responsable,
     usuario inactivo o contraseña errónea; el usuario debe tener rol `SERENO`;
     comparación bcrypt contra hash dummy si la unidad no existe (igualar tiempos);
     rate limit por IP y por placa con bloqueo temporal; la respuesta incluye
     `unidadId` y los mismos campos que `/auth/login`.
     **No** migrar hashes por placa del legacy (los de serenazgo.sql quedan
     descartados); las contraseñas nuevas se establecen con el script de
     credenciales. Las unidades PIE sin placa siguen entrando por DNI.
   - Búsqueda de unidad por placa.
   - `PATCH` y baja lógica de unidades.
   - `GET` zonas de calor (contrato de `docs/MAPABASE.md`).
   - `GET` catálogo de tipos de incidencia.

b) **Matriz de paridad**: cada pantalla/función Kotlin → equivalente Flutter →
   estado (hecho/parcial/falta), con capturas lado a lado. Base: auditoría de los
   15 métodos de `SerenazgoRepository` (1 equivalente, 5 adaptables, 9
   rotos/inexistentes).

c) **Tema idéntico**: auditar `mobile/lib/core/theme/app_theme.dart` contra los hex
   de los layouts del legacy (`res/layout/*.xml`; `colors.xml` solo tiene
   `verde #FF4CAF50`). Sin rediseñar nada.

d) **Orden en Flutter**: 1) login por rol; 2) SOS (`features/alertas`, hoy no
   existe); 3) mapa con OpenStreetMap (`flutter_map` ya está en pubspec; el legacy
   usa osmdroid 6.1.20, sin clave); 4) rastreo en segundo plano (Android: servicio
   en primer plano; iOS: permiso "siempre" y sus límites, documentados); 5) cliente
   WebSocket con reconexión y respaldo REST; 6) incidencias (existe); 7) mapa de
   calor; 8) búsqueda por placa y gestión de unidades.

e) **HITO SEMANA 8**: si SOS + mapa + rastreo no funcionan en Android contra la URL
   de Render, avisar para activar el respaldo en Kotlin.

f) Instalar el SDK de Flutter (`local.properties` apunta a `C:\Users\dahua\dev\flutter`,
   que no existe), ejecutar `flutter test` y `flutter analyze`, agregarlos al CI.

g) **iOS**: dejar el proyecto configurado (permisos, Info.plist, capacidades).
   **NO afirmar que funciona en iOS** sin ejecución real (dispositivo, simulador o
   TestFlight) con evidencia. Queda documentado como pendiente de Mac/dispositivo.

## Reglas vigentes

- Cero secretos en Git (aplica también al historial y al repo legacy).
- El informe debe coincidir con lo que existe (nada de "debería").
- No añadir push (FCM), panel web ni funciones fuera de H1–H6 y del MVP sin consultar.
